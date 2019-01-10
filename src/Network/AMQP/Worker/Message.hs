{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Message where

import           Control.Monad.Base             (liftBase)
import           Control.Monad.IO.Class         (MonadIO (..))
import           Data.Aeson                     (FromJSON, ToJSON)
import qualified Data.Aeson                     as Aeson
import           Data.ByteString.Lazy           (ByteString)
import           Network.AMQP                   (Ack (..), DeliveryMode (..),
                                                 QueueOpts (..), newMsg)
import qualified Network.AMQP                   as AMQP

import           Network.AMQP.Worker.Connection (Connection, withChannel)
import           Network.AMQP.Worker.Entity     (Declared, Exchange (..),
                                                 ExchangeName, ExchangeType,
                                                 Queue (..), RoutingKey, getMsg,
                                                 putMsg)
import           Network.AMQP.Worker.Poll       (poll)

-- types --------------------------

-- | a parsed message from the queue
data Message a = Message
  { body  :: ByteString
  , value :: a
  } deriving (Show, Eq)


data ConsumeResult a
  = Parsed (Message a)
  | Error ParseError

data ParseError = ParseError String ByteString

type Microseconds = Int


jsonMessage :: ToJSON a => a -> AMQP.Message
jsonMessage a = newMsg
  { AMQP.msgBody = Aeson.encode a
  , AMQP.msgContentType = Just "application/json"
  , AMQP.msgContentEncoding = Just "UTF-8"
  , AMQP.msgDeliveryMode = Just Persistent
  }

-- | publish a message to a queue. Enforces that the message type and queue name are correct at the type level
--
-- > let queue = Worker.queue exchange "users" :: Queue User
-- > publish conn queue (User "username")
publish :: (ExchangeType exchangeType, ToJSON msg, MonadIO m) => Connection -> Exchange Declared exchangeType msg -> RoutingKey exchangeType -> msg -> m ()
publish conn exchange filterKey = liftIO . putMsg conn exchange filterKey . jsonMessage

-- | Check for a message once and attempt to parse it
--
-- > res <- consume conn queue
-- > case res of
-- >   Just (Parsed m) -> print m
-- >   Just (Error e) -> putStrLn "could not parse message"
-- >   Notihng -> putStrLn "No messages on the queue"
consume :: (FromJSON msg, MonadIO m) => Connection -> Queue Declared msg -> m (Maybe (ConsumeResult msg))
consume conn queue = do
  result <- liftIO $ getMsg conn queue

  case result of
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
consumeNext :: (FromJSON msg, MonadIO m) => Microseconds -> Connection -> Queue Declared msg -> m (ConsumeResult msg)
consumeNext pd conn queue =
    poll pd $ consume conn queue
