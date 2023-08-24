{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.AMQP.Worker.Message where

import Control.Monad.Base (liftBase)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Aeson as Aeson
import Data.ByteString.Lazy (ByteString)
import Network.AMQP (Ack (..), DeliveryMode (..), newMsg)
import qualified Network.AMQP as AMQP

import Network.AMQP.Worker.Connection (Connection, exchange, withChannel)
import Network.AMQP.Worker.Key (Key, keyText)
import Network.AMQP.Worker.Poll (poll)
import Network.AMQP.Worker.Queue (Queue (..))

-- types --------------------------

-- | a parsed message from the queue
data Message a = Message
    { body :: ByteString
    , value :: a
    }
    deriving (Show, Eq)

data ConsumeResult a
    = Parsed (Message a)
    | Error ParseError

data ParseError = ParseError String ByteString

type Microseconds = Int

jsonMessage :: ToJSON a => a -> AMQP.Message
jsonMessage a =
    newMsg
        { AMQP.msgBody = Aeson.encode a
        , AMQP.msgContentType = Just "application/json"
        , AMQP.msgContentEncoding = Just "UTF-8"
        , AMQP.msgDeliveryMode = Just Persistent
        }

-- | publish a message to a routing key, without making sure a queue exists to handle it or if it is the right type of message body
--
-- > publishToExchange conn key (User "username")
publishToExchange :: (ToJSON a, MonadIO m) => Connection -> Key a -> a -> m ()
publishToExchange conn rk msg =
    liftIO $ withChannel conn $ \chan -> do
        _ <- AMQP.publishMsg chan (exchange conn) (keyText rk) (jsonMessage msg)
        return ()

-- | send a message to a queue. Enforces that the message type and queue name are correct at the type level
--
-- > publish conn (key "users" :: Key Routing User) (User "username")
publish :: (ToJSON a, MonadIO m) => Connection -> Key a -> a -> m ()
publish = publishToExchange

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
        m <- liftBase $ AMQP.getMsg chan Ack name
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

-- | Block while checking for messages every N microseconds. Return once you find one.
--
-- > res <- consumeNext conn queue
-- > case res of
-- >   (Parsed m) -> print m
-- >   (Error e) -> putStrLn "could not parse message"
consumeNext :: (FromJSON msg, MonadIO m) => Microseconds -> Connection -> Queue msg -> m (ConsumeResult msg)
consumeNext pd conn key =
    poll pd $ consume conn key
