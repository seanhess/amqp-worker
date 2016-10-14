{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
module Main where

import Control.Exception (SomeException(..))
import Control.Monad.Catch (Exception, throwM, catch)
import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Aeson as Aeson
import Data.Text (Text)
import GHC.Generics (Generic)
import qualified Network.Worker as Worker
import Network.Worker (fromURI, Exchange, Queue, Direct, WorkerException(..))

import qualified Data.ByteString.Lazy.Char8 as BL
import Network.AMQP (publishMsg, ExchangeOpts(..), QueueOpts(..), openConnection, openChannel, Message(..), declareQueue, declareExchange, bindQueue, newQueue, newExchange, consumeMsgs, Ack(..), newMsg, closeConnection, DeliveryMode(..))

data TestMessage = TestMessage
  { greeting :: Text }
  deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


exchange :: Exchange
exchange = Worker.exchange "testExchange"


queue :: Queue Direct TestMessage
queue = Worker.directQueue exchange "testQueue"


main :: IO ()
main = do
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

  Worker.initQueue conn queue
  -- Worker.publishToExchange conn "myExchange" "myQueue" (TestMessage "LKJLKJ")
  Worker.publish conn queue (TestMessage "woot")
  Worker.publish conn queue (TestMessage "woot2")
  -- Worker.publish conn queue (TestMessage "woot3")
  -- Worker.publish conn queue (TestMessage "woot4")
  -- Worker.publish conn queue (TestMessage "woot5")

  -- Worker.withChannel conn $ \chan ->
  --   publishMsg chan "testExchange" "testQueue"
  --       newMsg {msgBody = (BL.pack "hello world"),
  --               msgDeliveryMode = Just Persistent}

  Worker.worker conn queue onError work

  where
    work :: TestMessage -> IO ()
    work msg = do
      putStrLn ""
      putStrLn "NEW MESSAGE"
      print msg
      -- throwM (Fake "oh no")
      error "GRLKJ"

    onError :: BL.ByteString -> WorkerException SomeException -> IO ()
    onError body ex = do
      putStrLn ""
      putStrLn "Got an error"
      print body
      print ex


data Fake = Fake Text deriving (Show, Eq)
instance Exception Fake


woot = do
  conn <- openConnection "127.0.0.1" "/" "guest" "guest"
  chan <- openChannel conn

  -- declare a queue, exchange and binding
  declareQueue chan newQueue {queueName = "myQueue"}
  declareExchange chan newExchange {exchangeName = "myExchange", exchangeType = "direct"}
  bindQueue chan "myQueue" "myExchange" "myQueue"

  -- subscribe to the queue
  -- consumeMsgs chan "myQueue" Ack myCallback

  -- publish a message to our new exchange
  -- publishMsg chan "myExchange" "myQueue"
  --     newMsg {msgBody = (BL.pack "hello world"),
  --             msgDeliveryMode = Just Persistent}

  getLine -- wait for keypress
  closeConnection conn
  putStrLn "connection closed"
