{-# LANGUAGE FlexibleContexts #-}
module Network.AMQP.Worker.Connection
  ( Connection
  , connect
  , disconnect
  , withChannel
  ) where

import Control.Concurrent.MVar (MVar, putMVar, newEmptyMVar, readMVar, takeMVar)
import Control.Monad.Catch (throwM, catch)
import Data.Pool (Pool)
import qualified Data.Pool as Pool
import qualified Network.AMQP as AMQP
import Network.AMQP (Channel, AMQPException(..))
import Control.Monad.Trans.Control (MonadBaseControl)

data Connection =
  Connection (MVar AMQP.Connection) (Pool Channel)

-- | Connect to the AMQP server.
--
-- > conn <- connect (fromURI "amqp://guest:guest@localhost:5672")
--
connect :: AMQP.ConnectionOpts -> IO Connection
connect opts = do

    -- create a single connection in an mvar
    cvar <- newEmptyMVar
    openConnection cvar

    -- open a shared pool for channels
    chans <- Pool.createPool (create cvar) destroy numStripes openTime numChans


    pure $ Connection cvar chans
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


disconnect :: Connection -> IO ()
disconnect (Connection c p) = do
    conn <- readMVar c
    Pool.destroyAllResources p
    AMQP.closeConnection conn



withChannel :: MonadBaseControl IO m => Connection -> (Channel -> m b) -> m b
withChannel (Connection _ p) action = do
    Pool.withResource p action

