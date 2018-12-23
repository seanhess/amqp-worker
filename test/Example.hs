{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
module Main where

import Control.Monad.Catch (SomeException)
import Control.Concurrent (forkIO)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text, pack)
import GHC.Generics (Generic)
import qualified Network.AMQP.Worker as Worker
import Network.AMQP.Worker (fromURI, Exchange, Queue, def, WorkerException, Message(..), Connection)
import qualified Network.AMQP.Worker.Topic as Topic
import Network.AMQP.Worker.Key (Key, Routing, Binding)
import System.IO (hSetBuffering, stdout, stderr, BufferMode(..))

data TestMessage = TestMessage
  { greeting :: Text }
  deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


exchange :: Exchange
exchange = Worker.exchange "testExchange"


newMessages :: Key Routing TestMessage
newMessages = "messages.new"


-- ummmm :: Queue TestMessage
-- ummmm = Worker.queue "messages.*"


results :: Key Routing Text
results = "results"


example :: IO ()
example = do
  -- connect
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

  -- initialize the queues
  Worker.bindQueue conn exchange (Worker.direct newMessages)
  Worker.bindQueue conn exchange (Worker.direct results)

  -- topic queue!
  let handleAnyMessage = Worker.topic "messages.*" "handleAnyMessage"
  Worker.bindQueue conn exchange handleAnyMessage

  putStrLn "Enter a message"
  msg <- getLine

  -- publish a message
  putStrLn "Publishing a message"
  Worker.send conn exchange newMessages (TestMessage $ pack msg)

  -- create a worker, the program loops here
  -- Worker.worker def conn (Worker.direct newMessages) onError (onMessage conn)

  -- _ <- forkIO $ Worker.worker def conn ummmm onError (onMessage conn)

  putStrLn "Press any key to exit"
  _ <- getLine
  return ()




onMessage :: Connection -> Message TestMessage -> IO ()
onMessage conn m = do
  let testMessage = value m
  putStrLn "Got Message"
  print testMessage
  Worker.send conn exchange results (greeting testMessage)


onError :: WorkerException SomeException -> IO ()
onError e = do
  putStrLn "Do something with errors"
  print e



main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  example

