{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
module Network.Worker
  ( AMQP.fromURI
  , publish
  , publishToExchange
  , connect
  , disconnect
  , exchange
  , directQueue
  , topicQueue
  , initQueue
  , withChannel
  , consume
  , waitAndConsume
  , worker
  , RoutingKey(..)
  , BindingKey(..)
  , BindingName(..)
  , Exchange(..)
  , Queue(..)
  , Direct, Topic
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException(..))
import Control.Monad.Catch (throwM, MonadThrow, Exception(..))
import Control.Monad (forever)
import Data.Aeson (ToJSON, FromJSON)
import qualified Data.Aeson as Aeson
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable (Typeable)
import Data.Pool (Pool)
import qualified Data.Pool as Pool
import qualified Data.List as List
import qualified Data.List.Split as List
-- import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Network.AMQP as AMQP
import Network.AMQP (Message(..), Channel, newMsg, DeliveryMode(..), ExchangeOpts(..), QueueOpts(..), Ack(..))
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Trans.Control (MonadBaseControl)
import Control.Monad.Base (liftBase)


-- TODO when an exception happens handle it somehow?
-- TODO exception: make sure the connection still works
-- TODO worker in a loop.


-- TODO open a channel every time you want to use one: withChannel

-- TODO handle channel exception errors with addChannelExceptionHandler

-- TODO exchange and connection can be bundled together?
-- connection
-- exchange

class QueueKey key where
  showKey :: key -> Text

newtype RoutingKey = RoutingKey Text
  deriving (Show, Eq)

instance IsString RoutingKey where
  fromString = RoutingKey . Text.pack

instance QueueKey RoutingKey where
  showKey (RoutingKey t) = t


newtype BindingKey = BindingKey [BindingName]
  deriving (Eq)

instance QueueKey BindingKey where
  showKey (BindingKey ns) =
    Text.intercalate "." . List.map bindingNameText $ ns

instance IsString BindingKey where
  fromString s =
    let segments = List.splitOn "." s
        names = List.map fromString segments
    in BindingKey names


data BindingName
  = Name Text
  | Star
  | Hash
  deriving (Eq)

instance IsString BindingName where
  fromString "*" = Star
  fromString "#" = Hash
  fromString n = Name (Text.pack n)

bindingNameText :: BindingName -> Text
bindingNameText (Name t) = t
bindingNameText Star = "*"
bindingNameText Hash = "#"

type ExchangeName = Text


exchange :: Text -> Exchange
exchange nm =
  Exchange $ AMQP.newExchange { exchangeName = nm, exchangeType = "topic" }


topicQueue :: Exchange -> BindingKey -> Queue Topic msg
topicQueue exg key =
  Queue exg key $ AMQP.newQueue { queueName = showKey key }


directQueue :: Exchange -> RoutingKey -> Queue Direct msg
directQueue exg (RoutingKey key) =
  Queue exg (RoutingKey key) $ AMQP.newQueue { queueName = key }


newtype Exchange =
  Exchange AMQP.ExchangeOpts
  deriving (Show, Eq)

data Queue queueType msg =
  Queue Exchange queueType AMQP.QueueOpts
  deriving (Show, Eq)

type Direct = RoutingKey
type Topic = BindingKey



-- publish -----------------------------------------------

message :: ToJSON a => a -> Message
message a = newMsg
  { msgBody = Aeson.encode a
  , msgContentType = Just "application/json"
  , msgContentEncoding = Just "UTF-8"
  , msgDeliveryMode = Just Persistent
  }


-- but the exchange is tied to the connnection for sure?
publishToExchange :: (ToJSON a, MonadBaseControl IO m) => Connection -> ExchangeName -> RoutingKey -> a -> m ()
publishToExchange conn exg (RoutingKey rk) msg =
  withChannel conn $ \chan -> do
    liftBase $ print (exg, rk, message msg)
    _ <- liftBase $ AMQP.publishMsg chan exg rk (message msg)
    return ()


-- you can only publish to a direct queue
publish :: (ToJSON msg, MonadBaseControl IO m) => Connection -> Queue Direct msg -> msg -> m ()
publish conn (Queue (Exchange exg) key _) msg =
  publishToExchange conn (AMQP.exchangeName exg) key msg


-- TODO I need to surface parse errors, rather than acknowledging them and swallowing.
-- don't throw an error. Much easier to know what's going on.
consume :: (FromJSON msg, MonadBaseControl IO m, MonadThrow m) => Connection -> Queue key msg -> m (Maybe msg)
consume conn (Queue exg _ options) = do
  mme <- withChannel conn $ \chan ->
    liftBase $ AMQP.getMsg chan Ack (queueName options)

  case mme of
    Nothing -> return Nothing
    Just (msg, env) -> do
      liftBase $ AMQP.ackEnv env
      case Aeson.eitherDecode (msgBody msg) of
        Left err ->
          throwM $ ParseError err

        Right m ->
          return $ Just m



waitAndConsume :: (FromJSON msg, MonadBaseControl IO m, MonadThrow m) => Connection -> Queue key msg -> (msg -> m ()) -> m ()
waitAndConsume conn queue action = do
    m <- poll pollDelay $ consume conn queue
    action m

  where
    pollDelay = 1 * 1000



worker :: (FromJSON msg, MonadBaseControl IO m, MonadThrow m) => Connection -> Queue key msg -> (msg -> m ()) -> m ()
worker conn queue action =
  forever $ waitAndConsume conn queue action


data WorkerException
  = ParseError String
  deriving (Show, Typeable)

instance Exception WorkerException






poll :: (MonadBaseControl IO m) => Int -> m (Maybe a) -> m a
poll us action = do
    ma <- action
    case ma of
      Just a -> return a
      Nothing -> do
        liftBase $ threadDelay us
        poll us action




-- connections ----------------------------------------------

data ConnResource = ConnResource AMQP.Connection Channel

type Connection = Pool ConnResource

-- data.pool, if it throws an exception of any kind, the resource is destroyed and not returned to the pool
-- required: don't use the same channel for two concurrent requests
-- TODO how to use a single connection, and only re-open it when necessary? (exceptions can close the connection)
connect :: AMQP.ConnectionOpts -> IO Connection
connect opts =
    Pool.createPool create destroy numStripes openTime numResources
  where
    numStripes = 1
    openTime = 10
    numResources = 4

    create = do
      conn <- AMQP.openConnection'' opts
      chan <- AMQP.openChannel conn
      return $ ConnResource conn chan

    destroy (ConnResource conn _) =
      AMQP.closeConnection conn

disconnect :: Connection -> IO ()
disconnect conn =
    Pool.destroyAllResources conn



withChannel :: MonadBaseControl IO m => Connection -> (Channel -> m b) -> m b
withChannel conn action =
    Pool.withResource conn chanAction
  where
    chanAction (ConnResource _ chan) =
      action chan



-- takes a function that takes it as it's main argument?
-- worker :: (a -> m ()) -> m ()

-- myWorker :: IO ()
-- myWorker = do
--     conn <- connect (fromURI "amqp://localhost:5672")
--
--     -- publish conn (Destination "woot" "asdf.routing") "Hello"
--   where
--     exchange = j


-- 1. Declare Exchange: name, topic
-- 2. Declare Queue: name?,
-- 3. Bind Queue: exchange, routing key, queue

-- good defaults: Persistent, Durable, queues don't need a name


-- exchange: name
-- queue: exchange, routing key


-- routingkeys, just specify by hand


initQueue :: (QueueKey key) => Connection -> Queue key msg -> IO ()
initQueue conn (Queue (Exchange exg) key options) =
  withChannel conn $ \chan -> do
    _ <- AMQP.declareExchange chan exg
    _ <- AMQP.declareQueue chan options
    _ <- AMQP.bindQueue chan (AMQP.queueName options) (AMQP.exchangeName exg) (showKey key)
    return ()




-- you have to remember to give binding keys vs routing keys for when you send?
-- bah
-- what if I remove decisions? good defaults
-- default: topic queue
-- default: binding key = routing key
-- exchange and connection all rolled up
-- read from a different queue than you publish to

-- publish to a queue:





-- test :: IO ()
-- test = do
--     conn <- openConnection "127.0.0.1" "/" "guest" "guest"
--     chan <- openChannel conn
--
--     -- declare a queue, exchange and binding
--     (_, _, _) <- declareQueue chan newQueue { queueName = "myQueue" }
--     declareExchange chan newExchange { exchangeName = "myExchange", exchangeType = "direct" }
--     bindQueue chan "myQueue" "myExchange" "myKey"
--
--     -- subscribe to the queue
--     _ <- consumeMsgs chan "myQueue" NoAck myCallback
--
--     -- publish a message to our new exchange
--     _ <- publishMsg chan "myExchange" "myKey"
--       newMsg
--         { msgBody = BL.pack "hello world"
--         , msgDeliveryMode = Just Persistent
--         }
--
--     _ <- publishMsg chan "myExchange" "myKey"
--       newMsg
--         { msgBody = BL.pack "hello world 2 "
--         , msgDeliveryMode = Just Persistent
--         }
--
--     _ <- getLine -- wait for keypress
--     closeConnection conn
--     putStrLn "connection closed"
--
-- myCallback :: (Message, Envelope) -> IO ()
-- myCallback (msg, env) = do
--     putStrLn "received message"
--     print $ msgBody msg
--     -- acknowledge receiving the message
--     ackEnv env
