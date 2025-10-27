{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.AMQP.Worker.Connection
    ( Connection (..)
    , AMQP.ConnectionOpts (..)
    , AMQP.defaultConnectionOpts
    , ExchangeName
    , connect
    , disconnect
    , withChannel
    , parseURI
    , AMQP.fromURI
    ) where

import Control.Concurrent.MVar (MVar, newEmptyMVar, putMVar, readMVar, takeMVar)
import Control.Monad.Catch (Exception, MonadThrow, catch, throwM)
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

type URLString = String
data ConnectionError = InvalidConnectionURL URLString String
    deriving (Show, Exception)

parseURI :: (MonadThrow m) => URLString -> m AMQP.ConnectionOpts
parseURI u =
    case AMQP.fromURI u of
        Left err -> throwM $ InvalidConnectionURL u err
        Right a -> pure a

-- | Connect to the AMQP server.
--
-- > conn <- connect =<< parseURI "amqp://guest:guest@localhost:5672"
connect :: (MonadIO m) => AMQP.ConnectionOpts -> m Connection
connect opts = liftIO $ do
    -- use a default exchange name
    let exchangeName = "amq.topic"

    -- create a single connection in an mvar
    cvar <- newEmptyMVar
    openConnection cvar

    -- open a shared pool for channels
    chans <- Pool.newPool (config cvar)

    pure $ Connection cvar chans exchangeName
  where
    config cvar =
        Pool.defaultPoolConfig (create cvar) destroy openTime maxChans
            & Pool.setNumStripes (Just 1)

    openTime :: Double
    openTime = 10

    maxChans :: Int
    maxChans = 8

    openConnection cvar = do
        -- open a connection and store in the mvar
        conn <- AMQP.openConnection'' opts
        putMVar cvar conn

    reopenConnection cvar = do
        -- clear the mvar and reopen
        _ <- takeMVar cvar
        openConnection cvar

    create cvar = do
        conn <- readMVar cvar
        chan <- catch (AMQP.openChannel conn) (createEx cvar)
        return chan

    createEx cvar (ConnectionClosedException _ _) = do
        reopenConnection cvar
        create cvar
    createEx _ ex = throwM ex

    destroy chan = do
        AMQP.closeChannel chan

disconnect :: (MonadIO m) => Connection -> m ()
disconnect c = liftIO $ do
    conn <- readMVar $ amqpConn c
    Pool.destroyAllResources $ pool c
    AMQP.closeConnection conn

-- | Perform an action with a channel resource, and give it back at the end
withChannel :: Connection -> (Channel -> IO b) -> IO b
withChannel (Connection _ p _) action = do
    Pool.withResource p action
