{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Queue where

import Data.Text (pack)
import qualified Network.AMQP as AMQP
import Network.AMQP (QueueOpts(..))

import Network.AMQP.Worker.Key (Key(..), Routing, Binding)
import Network.AMQP.Worker.Connection (Connection, withChannel)
import Network.AMQP.Worker.Exchange (Exchange(..))



-- | Declare a direct queue with the name @Key Routing@. Direct queues work as you expect: you can publish messages to them and read from them.
--
-- > queue :: Queue Direct MyMessageType
-- > queue = Worker.queue exchange "testQueue"

queue :: Exchange -> Key Routing -> Queue Direct msg
queue exg key =
  Queue exg key $ AMQP.newQueue { queueName = pack $ show key }

-- | Declare a topic queue. Topic queues allow you to bind a queue to a dynamic address with wildcards
--
-- > queue :: Queue Topic MyMessageType
-- > queue = Worker.topicQueue exchange "new-users.*"

topicQueue :: Exchange -> Key Binding -> Queue Topic msg
topicQueue exg key =
  Queue exg key $ AMQP.newQueue { queueName = pack $ show key }


-- | Queues consist of an exchange, a type (Direct or Topic), and a message type
--
-- > queue :: Queue Direct MyMessageType
data Queue queueType msg =
  Queue Exchange queueType AMQP.QueueOpts
  deriving (Show, Eq)

type Direct = Key Routing

type Topic = Key Binding



-- | Register a queue and its exchange with the AMQP server. Call this before publishing or reading
--
-- > let queue = Worker.queue exchange "my-queue" :: Queue Direct Text
-- > conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- > Worker.initQueue conn queue

initQueue :: Show a => Connection -> Queue (Key a) msg -> IO ()
initQueue conn (Queue (Exchange exg) key options) =
  withChannel conn $ \chan -> do
    _ <- AMQP.declareExchange chan exg
    _ <- AMQP.declareQueue chan options
    _ <- AMQP.bindQueue chan (AMQP.queueName options) (AMQP.exchangeName exg) (pack $ show key)
    return ()
