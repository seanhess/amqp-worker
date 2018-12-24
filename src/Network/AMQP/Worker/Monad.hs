module Network.AMQP.Worker.Monad where

import Data.Aeson (ToJSON, FromJSON)
import Control.Exception (SomeException(..))
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Catch (MonadCatch)
import Network.AMQP.Worker.Key (Key, Routing)
import Network.AMQP.Worker.Exchange
import Network.AMQP.Worker.Connection
import Network.AMQP.Worker.Message (Message)
import Network.AMQP.Worker.Queue (Queue)
import Network.AMQP.Worker.Worker (WorkerOptions, WorkerException)
import qualified Network.AMQP.Worker.Queue as Queue
import qualified Network.AMQP.Worker.Message as Message
import qualified Network.AMQP.Worker.Worker as Worker


class (MonadIO m, MonadCatch m) => MonadWorker m where
    getConnection :: m Connection
    getExchange :: m Exchange


publish :: (ToJSON msg, MonadWorker m) => Key Routing msg -> msg -> m ()
publish key msg = do
    con <- getConnection
    exg <- getExchange
    Message.publish con exg key msg


bindQueue :: (MonadWorker m) => Queue msg -> m ()
bindQueue queue = do
    con <- getConnection
    exg <- getExchange
    Queue.bindQueue con exg queue


worker :: (FromJSON a, MonadWorker m) => WorkerOptions -> Queue a -> (WorkerException SomeException -> m ()) -> (Message a -> m ()) -> m ()
worker opts queue onError action = do
    con <- getConnection
    exg <- getExchange
    Worker.worker con exg opts queue onError action
