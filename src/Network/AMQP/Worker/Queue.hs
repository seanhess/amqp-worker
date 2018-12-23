{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Queue where

import Control.Monad.IO.Class (MonadIO, liftIO)
import qualified Network.AMQP as AMQP
import Network.AMQP (QueueOpts(..), ExchangeOpts(..))

import Network.AMQP.Worker.Key (Key(..), Routing, keyText)
import Network.AMQP.Worker.Connection (Connection, withChannel)
import Network.AMQP.Worker.Exchange (Exchange(..))





-- | Declare a queue. Queues support direct messaging: messages go to a queue with a specific name, where they persist until a worker consumes them. 
--
-- > queue :: Queue "testQueue" MyMessageType
-- > queue = Worker.queue exchange "testQueue"

queue :: Key Routing -> Queue msg
queue key = Queue key



data Queue msg =
  Queue (Key Routing)
  deriving (Show, Eq)




-- | Queues must be created before you publish messages to them, or the messages will not be saved.
--
-- > let queue = Worker.queue exchange "my-queue" :: Queue Direct Text
-- > conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- > Worker.initQueue conn queue

bindQueue :: (MonadIO m) => Connection -> Exchange -> Queue msg -> m ()
bindQueue conn (Exchange exgName) (Queue key) =
  liftIO $ withChannel conn $ \chan -> do
    let bindingName = keyText key
    let options = AMQP.newQueue { queueName = bindingName }
    let exg = AMQP.newExchange { exchangeName = exgName, exchangeType = "topic" }
    _ <- AMQP.declareExchange chan exg
    _ <- AMQP.declareQueue chan options
    _ <- AMQP.bindQueue chan bindingName exgName bindingName
    return ()
