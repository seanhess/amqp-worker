{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
module Main where

import Control.Monad.Catch (SomeException)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text, pack)
import GHC.Generics (Generic)
import qualified Network.AMQP.Worker as Worker
import Network.AMQP.Worker (fromURI, Exchange, Queue, def, WorkerException, Message(..), Connection)
import System.IO (hSetBuffering, stdout, stderr, BufferMode(..))

data TestMessage = TestMessage
  { greeting :: Text }
  deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


exchange :: Exchange
exchange = Worker.exchange "testExchange"


test :: Queue TestMessage
test = Worker.queue "testQueue"


results :: Queue Text
results = Worker.queue "resultQueue"


example :: IO ()
example = do
  -- connect
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

  -- initialize the queues
  Worker.bindQueue conn exchange test
  Worker.bindQueue conn exchange results

  putStrLn "Enter a message"
  msg <- getLine

  -- publish a message
  putStrLn "Publishing a message"
  Worker.publish conn exchange test (TestMessage $ pack msg)

  -- create a worker, the program loops here
  Worker.worker def conn test onError (onMessage conn)


onMessage :: Connection -> Message TestMessage -> IO ()
onMessage conn m = do
  let testMessage = value m
  putStrLn "Got Message"
  print testMessage
  Worker.publish conn exchange results (greeting testMessage)


onError :: WorkerException SomeException -> IO ()
onError e = do
  putStrLn "Do something with errors"
  print e



main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  example
