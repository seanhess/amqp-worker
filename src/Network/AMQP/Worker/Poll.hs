{-# LANGUAGE FlexibleContexts #-}

module Network.AMQP.Worker.Poll where

import Control.Concurrent (threadDelay)
import Control.Monad.Trans.Control (MonadBaseControl)
import Control.Monad.Base (liftBase)
import Control.Monad.Loops (untilJust)

poll :: (MonadBaseControl IO m) => Int -> m (Maybe a) -> m a
poll us action = untilJust $ do
    ma <- action
    case ma of
      Just a -> return $ Just a
      Nothing -> do
        liftBase $ threadDelay us
        return Nothing
