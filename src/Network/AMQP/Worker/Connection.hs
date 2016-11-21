{-# LANGUAGE FlexibleContexts #-}
module Network.AMQP.Worker.Connection
  ( Connection
  , connect
  , disconnect
  , withChannel
  ) where

import Data.Pool (Pool)
import qualified Data.Pool as Pool
import qualified Network.AMQP as AMQP
import Network.AMQP (Channel)
import Control.Monad.Trans.Control (MonadBaseControl)

data Connection =
  Connection AMQP.Connection (Pool Channel)

-- | Connect to the AMQP server.
--
-- > conn <- connect (fromURI "amqp://guest:guest@localhost:5672")
--
connect :: AMQP.ConnectionOpts -> IO Connection
connect opts = do

    -- open one connection
    conn <- AMQP.openConnection'' opts

    -- open a shared pool for channels
    chans <- Pool.createPool (create conn) destroy numStripes openTime numChans

    pure $ Connection conn chans
  where
    numStripes = 1
    openTime = 10
    numChans = 4

    create conn =
      AMQP.openChannel conn

    destroy chan =
      AMQP.closeChannel chan


disconnect :: Connection -> IO ()
disconnect (Connection c p) = do
    Pool.destroyAllResources p
    AMQP.closeConnection c



withChannel :: MonadBaseControl IO m => Connection -> (Channel -> m b) -> m b
withChannel (Connection _ p) action = do
    Pool.withResource p action
