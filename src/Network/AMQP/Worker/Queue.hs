{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Queue where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Text (pack)
import qualified Network.AMQP as AMQP
import Network.AMQP (QueueOpts(..))

import Network.AMQP.Worker.Key (Key(..), Routing)
import Network.AMQP.Worker.Connection (Connection, withChannel)
import Network.AMQP.Worker.Exchange (Exchange(..))





-- | Declare a queue. Queues support direct messaging: messages go to a queue with a specific name, where they persist until a worker consumes them. 
--
-- > queue :: Queue "testQueue" MyMessageType
-- > queue = Worker.queue exchange "testQueue"

queue :: Key Routing -> Queue msg
queue key =
  Queue key $ AMQP.newQueue { queueName = pack $ show key }



data Queue msg =
  Queue (Key Routing) AMQP.QueueOpts
  deriving (Show, Eq)




-- | Queues must be created before you publish messages to them, or the messages will not be saved.
--
-- > let queue = Worker.queue exchange "my-queue" :: Queue Direct Text
-- > conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- > Worker.initQueue conn queue

bindQueue :: (MonadIO m) => Connection -> Exchange -> Queue msg -> m ()
bindQueue conn (Exchange exg) (Queue key options) =
  liftIO $ withChannel conn $ \chan -> do
    _ <- AMQP.declareExchange chan exg
    _ <- AMQP.declareQueue chan options
    _ <- AMQP.bindQueue chan (AMQP.queueName options) (AMQP.exchangeName exg) (pack $ show key)
    return ()
