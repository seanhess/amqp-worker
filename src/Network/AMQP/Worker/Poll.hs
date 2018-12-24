{-# LANGUAGE FlexibleContexts #-}

module Network.AMQP.Worker.Poll where

import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Loops (untilJust)

poll :: (MonadIO m) => Int -> m (Maybe a) -> m a
poll us action = untilJust $ do
    ma <- action
    case ma of
      Just a -> return $ Just a
      Nothing -> do
        liftIO $ threadDelay us
        return Nothing
