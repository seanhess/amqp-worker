{-# LANGUAGE FlexibleContexts #-}
module Network.Worker.Connection
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

data ConnResource =
  ConnResource AMQP.Connection Channel


newtype Connection =
  Connection (Pool ConnResource)

-- | Connect to the AMQP server. This returns a connection pool. It will automatically re-open the connect if an exception occurs
--
-- > conn <- connect (fromURI "amqp://guest:guest@localhost:5672")
--
connect :: AMQP.ConnectionOpts -> IO Connection
connect opts = do
    p <- Pool.createPool create destroy numStripes openTime numResources
    pure $ Connection p
  where
    numStripes = 1
    openTime = 10
    numResources = 4

    create = do
      conn <- AMQP.openConnection'' opts
      chan <- AMQP.openChannel conn
      return $ ConnResource conn chan

    destroy (ConnResource conn _) =
      AMQP.closeConnection conn


disconnect :: Connection -> IO ()
disconnect (Connection p) =
    Pool.destroyAllResources p



withChannel :: MonadBaseControl IO m => Connection -> (Channel -> m b) -> m b
withChannel (Connection p) action =
    Pool.withResource p chanAction
  where
    chanAction (ConnResource _ chan) =
      action chan
