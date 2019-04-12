{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Connection
  ( Connection(..)
  , connect
  , disconnect
  , withChannel
  ) where

import           Control.Concurrent.MVar     (MVar, newEmptyMVar, putMVar,
                                              readMVar, takeMVar)
import           Control.Monad.Catch         (catch, throwM)
import           Control.Monad.IO.Class      (MonadIO, liftIO)
import           Control.Monad.Trans.Control (MonadBaseControl)
import           Data.Pool                   (Pool)
import qualified Data.Pool                   as Pool
import           Data.Text                   (Text)
import           Network.AMQP                (AMQPException (..), Channel)
import qualified Network.AMQP                as AMQP

type ExchangeName = Text


-- | Internal connection details
data Connection = Connection
  { amqpConn :: MVar AMQP.Connection
  , pool     :: Pool Channel
  , exchange :: ExchangeName
  }

-- | Connect to the AMQP server.
--
-- > conn <- connect (fromURI "amqp://guest:guest@localhost:5672")
connect :: MonadIO m => AMQP.ConnectionOpts -> m Connection
connect opts = liftIO $ do

    -- use a default exchange name
    let exchangeName = "amq.topic"

    -- create a single connection in an mvar
    cvar <- newEmptyMVar
    openConnection cvar

    -- open a shared pool for channels
    chans <- Pool.createPool (create cvar) destroy numStripes openTime numChans


    pure $ Connection cvar chans exchangeName
  where
    numStripes = 1
    openTime = 10
    numChans = 4

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


disconnect :: MonadIO m => Connection -> m ()
disconnect c = liftIO $ do
    conn <- readMVar $ amqpConn c
    Pool.destroyAllResources $ pool c
    AMQP.closeConnection conn



-- | Perform an action with a channel resource
withChannel :: MonadBaseControl IO m => Connection -> (Channel -> m b) -> m b
withChannel (Connection _ p _) action = do
    Pool.withResource p action
