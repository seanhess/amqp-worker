{-# LANGUAGE OverloadedStrings #-}

module Network.AMQP.Worker.Queue where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Text (Text)
import Network.AMQP (ExchangeOpts (..), QueueOpts)
import qualified Network.AMQP as AMQP

import Network.AMQP.Worker.Connection (Connection, exchange, withChannel)
import Network.AMQP.Worker.Key (Key (..), keyText)

type QueueName = Text

-- | A queue is an inbox for messages to be delivered
data Queue msg
    = Queue (Key msg) QueueName
    deriving (Show, Eq)

-- | Create a queue and bind it, allowing it to receive messages. Each unique
-- key name bound to that key will receive a copy of the message
queue :: (MonadIO m) => Connection -> QueueName -> Key msg -> m (Queue msg)
queue conn name key = do
    let q = Queue key name
    bindQueue conn q
    return q

-- | Create a queue, using the routing key as a name. Duplicate queue names refer
-- to the same queue and workers bound to each will load balance, consuming each
-- message only once.
--
-- If you want to receive a message twice, call `queue` with unique names
queue' :: (MonadIO m) => Connection -> Key msg -> m (Queue msg)
queue' conn key = queue conn (queueName "main" key) key

-- | Name a queue with a prefix and the routing key name. Useful for seeing at
-- a glance which queues are receiving which messages
queueName :: Text -> Key msg -> QueueName
queueName prefix key = prefix <> " " <> keyText key

-- | Queues must be bound before you publish messages to them, or the messages will not be saved.
-- Use `queue` or `queue'` instead
bindQueue :: (MonadIO m) => Connection -> Queue msg -> m ()
bindQueue conn (Queue key name) =
    liftIO $ withChannel conn $ \chan -> do
        let options = AMQP.newQueue{AMQP.queueName = name}
        let exg = AMQP.newExchange{exchangeName = exchange conn, exchangeType = "topic"}
        _ <- AMQP.declareExchange chan exg
        _ <- AMQP.declareQueue chan options
        _ <- AMQP.bindQueue chan name (exchange conn) (keyText key)
        return ()
