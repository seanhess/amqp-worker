    {-# LANGUAGE OverloadedStrings #-}
    {-# LANGUAGE DeriveGeneric #-}
    module Main where

    import Control.Concurrent (forkIO)
    import Data.Aeson (FromJSON, ToJSON)
    import qualified Data.Aeson as Aeson
    import Data.Text (Text)
    import GHC.Generics (Generic)
    import qualified Network.Worker as Worker
    import Network.Worker (fromURI, Exchange, Queue, Direct, WorkerException(..))

    data TestMessage = TestMessage
      { greeting :: Text }
      deriving (Generic, Show, Eq)

    instance FromJSON TestMessage
    instance ToJSON TestMessage


    exchange :: Exchange
    exchange = Worker.exchange "testExchange"


    queue :: Queue Direct TestMessage
    queue = Worker.directQueue exchange "testQueue"


    results :: Queue Direct Text
    results = Worker.directQueue exchange "resultQueue"


    example :: IO ()
    example = do
      conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

      Worker.initQueue conn queue
      Worker.initQueue conn results

      Worker.publish conn queue (TestMessage "hello world")

      forkIO $ Worker.worker conn queue onError $ \msg -> do
        putStrLn ""
        putStrLn "NEW MESSAGE"
        print msg
        Worker.publish conn results (greeting msg)
        error "This will trigger an error"

      -- normally you would only have one worker per program
      -- but here we are showing how you can send results to the next queue
      forkIO $ Worker.worker conn results onError $ \msg -> do
        putStrLn ""
        putStrLn "RESULT"
        print msg

      -- close if the user hits any key
      _ <- getLine

      Worker.disconnect conn

      where
        onError body ex = do
          putStrLn ""
          putStrLn "Got an error"
          print body
          print ex
