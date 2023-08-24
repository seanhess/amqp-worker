{-# LANGUAGE FlexibleContexts #-}

module Network.AMQP.Worker.Worker where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException (..))
import Control.Monad (forever)
import Control.Monad.Catch (Exception (..), MonadCatch, catch)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson (FromJSON)
import Data.ByteString.Lazy (ByteString)
import Data.Default (Default (..))

import Network.AMQP.Worker.Connection (Connection)
import Network.AMQP.Worker.Message (ConsumeResult (..), Message (..), Microseconds, ParseError (..), consumeNext)
import Network.AMQP.Worker.Queue (Queue (..))

-- | Create a worker which loops, checks for messages, and handles errors
--
-- > startWorker conn queue = do
-- >   Worker.worker conn def queue onError onMessage
-- >
-- >   where
-- >     onMessage :: Message User
-- >     onMessage m = do
-- >       putStrLn "handle user message"
-- >       print (value m)
-- >
-- >     onError :: WorkerException SomeException -> IO ()
-- >     onError e = do
-- >       putStrLn "Do something with errors"
worker :: (FromJSON a, MonadIO m, MonadCatch m) => Connection -> WorkerOptions -> Queue a -> (WorkerException SomeException -> m ()) -> (Message a -> m ()) -> m ()
worker conn opts queue onError action =
    forever $ do
        eres <- consumeNext (pollDelay opts) conn queue
        case eres of
            Error (ParseError reason bd) ->
                onError (MessageParseError bd reason)
            Parsed msg ->
                catch
                    (action msg)
                    (onError . OtherException (body msg))
        liftIO $ threadDelay (loopDelay opts)

-- | Options for worker
data WorkerOptions = WorkerOptions
    { pollDelay :: Microseconds
    -- ^ Delay between checks to consume. Defaults to 10ms
    , loopDelay :: Microseconds
    -- ^ Delay between calls to job. Defaults to 0
    }
    deriving (Show, Eq)

instance Default WorkerOptions where
    def =
        WorkerOptions
            { pollDelay = 10 * 1000
            , loopDelay = 0
            }

-- | Exceptions created while processing
data WorkerException e
    = MessageParseError ByteString String
    | OtherException ByteString e
    deriving (Show, Eq)

instance (Exception e) => Exception (WorkerException e)
