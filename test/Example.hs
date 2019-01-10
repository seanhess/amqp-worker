{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Control.Concurrent  (forkIO, threadDelay)
import           Control.Monad       (void)
import           Control.Monad.Catch (SomeException)
import           Data.Aeson          (FromJSON, ToJSON)
import           Data.Text           (Text)
import           GHC.Generics        (Generic)
import           Network.AMQP.Worker (Connection, Declared, Defined, Direct,
                                      Exchange, Fanout, Message (..), Queue,
                                      Topic, WorkerException, def, fromURI)
import qualified Network.AMQP.Worker as Worker
import           System.IO           (BufferMode (..), hSetBuffering, stderr,
                                      stdout)

newtype TestMessage = TestMessage { greeting :: Text } deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


directExchange :: Exchange Defined Direct TestMessage
directExchange = "testExchange"

fanoutExchange :: Exchange Defined Fanout TestMessage
fanoutExchange = "testFanoutExchange"

queue1 :: Queue Defined TestMessage
queue1 = "testQueue1"

queue2 :: Queue Defined TestMessage
queue2 = "testQueue2"

directResultExchange :: Exchange Defined Direct Text
directResultExchange = "testResults"

results :: Queue Defined Text
results = "resultQueue"


example :: IO ()
example = do

  -- connect
  -- The "Connection" has information about the exchange in it? Yeah, we always use a topic exchange anyway.
  -- they can specify some defaults here
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

  -- initialize the exchanges
  direct   <- Worker.declareExchange conn directExchange
  fanout   <- Worker.declareExchange conn fanoutExchange
  topic    <- Worker.declareExchange conn ("testTopicExchange" :: Exchange Defined Topic TestMessage)
  resultsX <- Worker.declareExchange conn directResultExchange

  -- initialize the queues
  queue1'  <- Worker.declareQueue conn queue1
  queue2'  <- Worker.declareQueue conn queue2
  results' <- Worker.declareQueue conn results

  Worker.bindQueue conn direct queue1' "q1"
  Worker.bindQueue conn direct queue2' "q2"

  Worker.bindQueue conn fanout queue1' ()
  Worker.bindQueue conn fanout queue2' ()

  Worker.bindQueue conn topic queue1' "a.*"
  Worker.bindQueue conn topic queue2' "*.x"

  Worker.bindQueue conn resultsX results' "r"

  -- create workers in threads, the program loops here
  void . forkIO $ Worker.worker def conn queue1'  (onError "q1") (onTestMessage "q1" conn resultsX)
  void . forkIO $ Worker.worker def conn queue2'  (onError "q2") (onTestMessage "q2" conn resultsX)
  void . forkIO $ Worker.worker def conn results' (onError "r") (onReply "r")


  putStrLn "Exercising Direct Exchange support"
  Worker.publish conn direct "q1" (TestMessage "hello world")

  threadDelay (100 * 1000)


  putStrLn "Exercising Fanout Exchange support"
  Worker.publish conn fanout () (TestMessage "Hello Fanout!")

  threadDelay (100 * 1000)


  putStrLn "Exercising Topic Exchange support"
  Worker.publish conn topic "a.x" (TestMessage "Hello Topic!")

  threadDelay (100 * 1000)


onTestMessage :: String -> Connection -> Exchange Declared Direct Text -> Message TestMessage -> IO ()
onTestMessage prefix conn exch m = do
  let testMessage = value m

  putStr (prefix <> ": ")
  putStrLn "Got Message"

  putStr (prefix <> ": ")
  print testMessage

  Worker.publish conn exch "r" (greeting testMessage)

onReply :: String -> Message Text -> IO ()
onReply prefix msg = do
  putStr (prefix <> ": ")
  putStrLn "Got Reply"

  putStr (prefix <> ": ")
  print msg

onError :: String -> WorkerException SomeException -> IO ()
onError prefix e = do
  putStr (prefix <> ": ")
  putStrLn "Do something with errors"

  putStr (prefix <> ": ")
  print e



main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  example
