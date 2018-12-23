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
import System.IO (hSetBuffering, stdout, stderr, BufferMode(..))

data TestMessage = TestMessage
  { greeting :: Text }
  deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


exchange :: Exchange
exchange = Worker.exchange "testExchange"


newMessages :: Queue TestMessage
newMessages = Worker.queue "messages.new"


ummmm :: Queue TestMessage
ummmm = Worker.queue "messages.*"


results :: Queue Text
results = Worker.queue "results"


example :: IO ()
example = do
  -- connect
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

  -- initialize the queues
  Worker.bindQueue conn exchange newMessages
  Worker.bindQueue conn exchange ummmm
  Worker.bindQueue conn exchange results

  putStrLn "Enter a message"
  msg <- getLine

  -- publish a message
  putStrLn "Publishing a message"
  Worker.send conn exchange newMessages (TestMessage $ pack msg)

  -- create a worker, the program loops here
  _ <- forkIO $ Worker.worker def conn newMessages onError (onMessage conn)

  _ <- forkIO $ Worker.worker def conn ummmm onError (onMessage conn)

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

