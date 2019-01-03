{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
module Main where

-- TODO queue names are global! they don't belong to an exchange at all. You publish to an exchange. An exchange decides how to route ot queues, but the queues themselves are totally independent.
-- the exchange hardly matters then

import Control.Monad.Catch (SomeException)
import Control.Concurrent (forkIO)
import Data.Function ((&))
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text, pack)
import GHC.Generics (Generic)
import qualified Network.AMQP.Worker as Worker
import Network.AMQP.Worker (fromURI, def, WorkerException, Message(..), Connection)
import Network.AMQP.Worker.Key
import System.IO (hSetBuffering, stdout, stderr, BufferMode(..))

data TestMessage = TestMessage
  { greeting :: Text }
  deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


newMessages :: Key Routing TestMessage
newMessages = key "messages" & word "new"

results :: Key Routing Text
results = key "results"

anyMessages :: Key Binding TestMessage
anyMessages = key "messages" & star



example :: IO ()
example = do

  -- connect
  -- The "Connection" has information about the exchange in it? Yeah, we always use a topic exchange anyway.
  -- they can specify some defaults here
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

  let handleAnyMessages = Worker.topic anyMessages "handleAnyMessage"

  -- initialize the queues
  Worker.bindQueue conn (Worker.direct newMessages)
  Worker.bindQueue conn (Worker.direct results)

  -- topic queue!
  Worker.bindQueue conn handleAnyMessages

  putStrLn "Enter a message"
  msg <- getLine

  -- publish a message
  putStrLn "Publishing a message"
  Worker.publish conn newMessages (TestMessage $ pack msg)

  -- create a worker, the program loops here
  _ <- forkIO $ Worker.worker conn def (Worker.direct newMessages) onError (onMessage conn)
  _ <- forkIO $ Worker.worker conn def (handleAnyMessages) onError (onMessage conn)

  -- _ <- forkIO $ Worker.worker def conn ummmm onError (onMessage conn)

  putStrLn "Press any key to exit"
  _ <- getLine
  return ()




onMessage :: Connection -> Message TestMessage -> IO ()
onMessage conn m = do
  let testMessage = value m
  putStrLn "Got Message"
  print testMessage
  Worker.publish conn results (greeting testMessage)


onError :: WorkerException SomeException -> IO ()
onError e = do
  putStrLn "Do something with errors"
  print e



main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  example

