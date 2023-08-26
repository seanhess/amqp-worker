{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.AMQP.Worker.Queue where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Default (Default (..))
import Data.String (IsString)
import Data.Text (Text)
import Network.AMQP (ExchangeOpts (..), QueueOpts)
import qualified Network.AMQP as AMQP

import Network.AMQP.Worker.Connection (Connection, exchange, withChannel)
import Network.AMQP.Worker.Key (Bind, Key (..), keyText, toBindKey)

type QueueName = Text

newtype QueuePrefix = QueuePrefix Text
    deriving (Show, Eq, IsString)

instance Default QueuePrefix where
    def = QueuePrefix "main"

-- | A queue is an inbox for messages to be delivered
data Queue msg
    = Queue (Key Bind msg) QueueName
    deriving (Show, Eq)

-- | Create a queue to receive messages matching the 'Key' with a name prefixed via `queueName`.
--
-- > q <- Worker.queue conn "main" $ key "messages" & any1
-- > Worker.worker conn def q onError onMessage
queue :: (MonadIO m) => Connection -> QueuePrefix -> Key a msg -> m (Queue msg)
queue conn pre key = do
    queueNamed conn (queueName pre key) key

-- | Create a queue to receive messages matching the binding key. Each queue with a unique name
-- will be delivered a separate copy of the messsage. Workers operating on the same queue,
-- or on queues with the same name will load balance
queueNamed :: (MonadIO m) => Connection -> QueueName -> Key a msg -> m (Queue msg)
queueNamed conn name key = do
    let q = Queue (toBindKey key) name
    bindQueue conn q
    return q

-- | Name a queue with a prefix and the binding key name. Useful for seeing at
-- a glance which queues are receiving which messages
--
-- > -- "main messages.new"
-- > queueName "main" (key "messages" & word "new")
queueName :: QueuePrefix -> Key a msg -> QueueName
queueName (QueuePrefix pre) key = pre <> " " <> keyText key

-- | Queues must be bound before you publish messages to them, or the messages will not be saved.
-- Use `queue` or `queueNamed` instead
bindQueue :: (MonadIO m) => Connection -> Queue msg -> m ()
bindQueue conn (Queue key name) =
    liftIO $ withChannel conn $ \chan -> do
        let options = AMQP.newQueue{AMQP.queueName = name}
        let exg = AMQP.newExchange{exchangeName = exchange conn, exchangeType = "topic"}
        _ <- AMQP.declareExchange chan exg
        _ <- AMQP.declareQueue chan options
        _ <- AMQP.bindQueue chan name (exchange conn) (keyText key)
        return ()
