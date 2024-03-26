{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.AMQP.Worker.Connection
    ( connect
    , connect'
    , disconnect
    , withChannel
    , Connection (..)
    , WorkerOpts (..)
    , ExchangeName
    , AMQP.ConnectionOpts (..)
    , AMQP.defaultConnectionOpts
    , AMQP.fromURI
    ) where

import Control.Concurrent.MVar (MVar, newEmptyMVar, putMVar, readMVar, takeMVar)
import Control.Monad.Catch (catch, throwM)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Function ((&))
import Data.Pool (Pool)
import qualified Data.Pool as Pool
import Data.Text (Text)
import Network.AMQP (AMQPException (..), Channel)
import qualified Network.AMQP as AMQP

type ExchangeName = Text

data Connection = Connection
    { amqpConn :: MVar AMQP.Connection
    , pool :: Pool Channel
    , exchange :: ExchangeName
    }

data WorkerOpts = WorkerOpts
    { exchange :: ExchangeName
    -- ^ Everything goes on one exchange
    , openTime :: Double
    -- ^ Number of seconds connections in the pool remain open for re-use
    , maxChannels :: Int
    -- ^ Number of concurrent connectinos available in the pool
    , numStripes :: Maybe Int
    }
    deriving (Show, Eq)

-- | Connect to the AMQP server using simple defaults
--
-- > conn <- connect (fromURI "amqp://guest:guest@localhost:5672")
connect :: MonadIO m => AMQP.ConnectionOpts -> m Connection
connect opts =
    connect' opts $
        WorkerOpts
            { exchange = "amq.topic"
            , openTime = 10
            , maxChannels = 8
            , numStripes = Just 1
            }

connect' :: MonadIO m => AMQP.ConnectionOpts -> WorkerOpts -> m Connection
connect' copt wopt = liftIO $ do
    -- create a single connection in an mvar
    cvar <- newEmptyMVar
    openConnection cvar

    -- open a shared pool for channels
    chans <- Pool.newPool (config cvar)

    pure $ Connection cvar chans wopt.exchange
  where
    config cvar =
        Pool.defaultPoolConfig (create cvar) destroy wopt.openTime wopt.maxChannels
            & Pool.setNumStripes wopt.numStripes

    openConnection cvar = do
        -- open a connection and store in the mvar
        conn <- AMQP.openConnection'' copt
        putMVar cvar conn

    reopenConnection cvar = do
        -- clear the mvar and reopen
        _ <- takeMVar cvar
        openConnection cvar

    create cvar = do
        conn <- readMVar cvar
        catch (AMQP.openChannel conn) (createEx cvar)

    -- Reopen closed connections
    createEx cvar (ConnectionClosedException _ _) = do
        reopenConnection cvar
        create cvar
    createEx _ ex = throwM ex

    destroy chan = do
        AMQP.closeChannel chan

disconnect :: MonadIO m => Connection -> m ()
disconnect c = liftIO $ do
    conn <- readMVar $ amqpConn c
    Pool.destroyAllResources $ pool c
    AMQP.closeConnection conn

-- | Perform an action with a channel resource, and give it back at the end
withChannel :: Connection -> (Channel -> IO b) -> IO b
withChannel (Connection _ p _) action = do
    Pool.withResource p action
