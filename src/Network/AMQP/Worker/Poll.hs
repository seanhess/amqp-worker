{-# LANGUAGE FlexibleContexts #-}

module Network.AMQP.Worker.Poll where

import Control.Concurrent (threadDelay)
import Control.Monad.Trans.Control (MonadBaseControl)
import Control.Monad.Base (liftBase)

poll :: (MonadBaseControl IO m) => Int -> m (Maybe a) -> m a
poll us action = do
    ma <- action
    case ma of
      Just a -> return a
      Nothing -> do
        liftBase $ threadDelay us
        poll us action
