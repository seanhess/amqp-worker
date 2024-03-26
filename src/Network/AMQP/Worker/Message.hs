{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Network.AMQP.Worker.Message where

import Control.Exception (Exception, throwIO)
import Control.Monad (forever)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Aeson as Aeson
import Data.ByteString.Lazy (ByteString)
import Network.AMQP (Ack (..), DeliveryMode (..), newMsg)
import qualified Network.AMQP as AMQP
import Network.AMQP.Worker.Connection (Connection (..), withChannel)
import Network.AMQP.Worker.Key (Key, RequireRoute, Route, keyText)
import Network.AMQP.Worker.Poll (poll)
import Network.AMQP.Worker.Queue (Queue (..))

-- | a parsed message from the queue
data Message a = Message
    { body :: ByteString
    , value :: a
    }
    deriving (Show, Eq)

-- | send a message to a queue. Enforces that the message type and queue name are correct at the type level
--
-- > let newUsers = key "users" & word "new" :: Key Route User
-- > publish conn newUsers (User "username")
--
-- Publishing to a Binding Key results in an error
--
-- > -- Compiler error! This doesn't make sense
-- > let users = key "users" & many :: Key Binding User
-- > publish conn users (User "username")
publish :: (RequireRoute a, ToJSON msg, MonadIO m) => Connection -> Key a msg -> msg -> m ()
publish = publishToExchange

-- | publish a message to a routing key, without making sure a queue exists to handle it
--
-- > publishToExchange conn key (User "username")
publishToExchange :: (RequireRoute a, ToJSON msg, MonadIO m) => Connection -> Key a msg -> msg -> m ()
publishToExchange conn rk msg =
    liftIO $ withChannel conn $ \chan -> do
        _ <- AMQP.publishMsg chan conn.exchange (keyText rk) (jsonMessage msg)
        return ()
  where
    jsonMessage :: ToJSON a => a -> AMQP.Message
    jsonMessage a =
        newMsg
            { AMQP.msgBody = Aeson.encode a
            , AMQP.msgContentType = Just "application/json"
            , AMQP.msgContentEncoding = Just "UTF-8"
            , AMQP.msgDeliveryMode = Just Persistent
            }

-- | Wait until a message is read from the queue. Throws an exception if the incoming message doesn't match the key type
--
-- > m <- Worker.takeMessage conn queue
-- > print (value m)
takeMessage :: (MonadIO m, FromJSON a) => Connection -> Queue a -> m (Message a)
takeMessage conn q = do
    let delay = 10000 :: Microseconds
    res <- consumeNext delay conn q
    case res of
        Error e -> liftIO $ throwIO e
        Parsed msg -> pure msg

-- | Create a worker which loops and handles messages. Throws an exception if the incoming message doesn't match the key type.
-- It is recommended that you catch errors in your handler and allow message parsing errors to crash your program.
--
-- > Worker.worker conn queue $ \m -> do
-- >   print (value m)
worker :: (FromJSON a, MonadIO m) => Connection -> Queue a -> (Message a -> m ()) -> m ()
worker conn queue action =
    forever $ do
        m <- takeMessage conn queue
        action m

-- | Block while checking for messages every N microseconds. Return once you find one.
--
-- > res <- consumeNext conn queue
-- > case res of
-- >   (Parsed m) -> print m
-- >   (Error e) -> putStrLn "could not parse message"
consumeNext :: (FromJSON msg, MonadIO m) => Microseconds -> Connection -> Queue msg -> m (ConsumeResult msg)
consumeNext pd conn key =
    poll pd $ consume conn key

-- | Check for a message once and attempt to parse it
--
-- > res <- consume conn queue
-- > case res of
-- >   Just (Parsed m) -> print m
-- >   Just (Error e) -> putStrLn "could not parse message"
-- >   Nothing -> putStrLn "No messages on the queue"
consume :: (FromJSON msg, MonadIO m) => Connection -> Queue msg -> m (Maybe (ConsumeResult msg))
consume conn (Queue _ name) = do
    mme <- liftIO $ withChannel conn $ \chan -> do
        m <- AMQP.getMsg chan Ack name
        pure m

    case mme of
        Nothing ->
            return Nothing
        Just (msg, env) -> do
            liftIO $ AMQP.ackEnv env
            let bd = AMQP.msgBody msg
            case Aeson.eitherDecode bd of
                Left err ->
                    return $ Just $ Error (ParseError err bd)
                Right v ->
                    return $ Just $ Parsed (Message bd v)

data ConsumeResult a
    = Parsed (Message a)
    | Error ParseError

data ParseError = ParseError String ByteString
    deriving (Show, Exception)

type Microseconds = Int
