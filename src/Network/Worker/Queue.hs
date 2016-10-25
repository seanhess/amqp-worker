{-# LANGUAGE OverloadedStrings #-}
module Network.Worker.Queue where

import Data.Text (Text)
import qualified Network.AMQP as AMQP
import Network.AMQP (ExchangeOpts(..), QueueOpts(..))

import Network.Worker.Key (RoutingKey(..), BindingKey(..), QueueKey(..))
import Network.Worker.Connection (Connection, withChannel)


type ExchangeName = Text


-- | Declare an exchange
--
-- In AMQP, exchanges can be fanout, direct, or topic. This library attempts to simplify this choice by making all exchanges be topic exchanges, and allowing the user to specify topic or direct behavior on the queue itself. See @queue@
--
-- > exchange :: Exchange
-- > exchange = Worker.exchange "testExchange"

exchange :: ExchangeName -> Exchange
exchange nm =
  Exchange $ AMQP.newExchange { exchangeName = nm, exchangeType = "topic" }

-- | Declare a direct queue with the name @RoutingKey@. Direct queues work as you expect: you can publish messages to them and read from them.
--
-- > queue :: Queue Direct MyMessageType
-- > queue = Worker.queue exchange "testQueue"

queue :: Exchange -> RoutingKey -> Queue Direct msg
queue exg (RoutingKey key) =
  Queue exg (RoutingKey key) $ AMQP.newQueue { queueName = key }

-- | Declare a topic queue. Topic queues allow you to bind a queue to a dynamic address with wildcards
--
-- > queue :: Queue Topic MyMessageType
-- > queue = Worker.topicQueue exchange "new-users.*"

topicQueue :: Exchange -> BindingKey -> Queue Topic msg
topicQueue exg key =
  Queue exg key $ AMQP.newQueue { queueName = showKey key }


data Exchange =
  Exchange AMQP.ExchangeOpts
  deriving (Show, Eq)

-- | Queues consist of an exchange, a type (Direct or Topic), and a message type
--
-- > queue :: Queue Direct MyMessageType
data Queue queueType msg =
  Queue Exchange queueType AMQP.QueueOpts
  deriving (Show, Eq)

type Direct = RoutingKey

type Topic = BindingKey



-- | Register a queue and its exchange with the AMQP server. Call this before publishing or reading
--
-- > let queue = Worker.queue exchange "my-queue" :: Queue Direct Text
-- > conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- > Worker.initQueue conn queue

initQueue :: (QueueKey key) => Connection -> Queue key msg -> IO ()
initQueue conn (Queue (Exchange exg) key options) =
  withChannel conn $ \chan -> do
    _ <- AMQP.declareExchange chan exg
    _ <- AMQP.declareQueue chan options
    _ <- AMQP.bindQueue chan (AMQP.queueName options) (AMQP.exchangeName exg) (showKey key)
    return ()
