{-# LANGUAGE FlexibleContexts #-}
module Network.AMQP.Worker.Connection
  ( Connection
  , connect
  , disconnect
  , withChannel
  ) where

import Control.Concurrent.MVar (readMVar, newEmptyMVar, putMVar)
import Data.Pool (Pool)
import qualified Data.Pool as Pool
import qualified Network.AMQP as AMQP
import Network.AMQP (Channel)
import Control.Monad.Trans.Control (MonadBaseControl)

newtype Connection =
  Connection (Pool Channel)

-- | Connect to the AMQP server. This returns a connection pool which will automatically re-open the connection as needed if an exception occurs.
--
-- > conn <- connect (fromURI "amqp://guest:guest@localhost:5672")
--
connect :: AMQP.ConnectionOpts -> IO Connection
connect opts = do

    chansVar <- newEmptyMVar

    -- keep one connection open
    conns <- Pool.createPool createConn (destroyConn chansVar) 1 connOpenTime 1

    -- the channels use the pool to create themselves
    chans <- Pool.createPool (create conns) destroy numStripes openTime numResources

    putMVar chansVar chans

    pure $ Connection chans
  where
    numStripes = 1
    openTime = 10
    numResources = 4
    connOpenTime = 60

    create connPool = do
      Pool.withResource connPool $ AMQP.openChannel

    destroy chan = do
      AMQP.closeChannel chan

    createConn = do
      conn <- AMQP.openConnection'' opts
      pure conn

    destroyConn chans conn = do
      -- destroy all channels or they will be stale and throw exceptions
      chanPool <- readMVar chans
      Pool.destroyAllResources chanPool
      AMQP.closeConnection conn


disconnect :: Connection -> IO ()
disconnect (Connection p) =
    Pool.destroyAllResources p



withChannel :: MonadBaseControl IO m => Connection -> (Channel -> m b) -> m b
withChannel (Connection p) action =
    Pool.withResource p action
