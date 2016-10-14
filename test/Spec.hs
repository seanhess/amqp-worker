{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
module Main where

import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Aeson as Aeson
import Data.Text (Text)
import GHC.Generics (Generic)
import qualified Network.Worker as Worker
import Network.Worker (fromURI, Exchange, Queue, Direct)

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

  m <- Worker.consume conn queue
  m1 <- Worker.consume conn queue
  m2 <- Worker.consume conn queue
  m3 <- Worker.consume conn queue
  m4 <- Worker.consume conn queue
  m5 <- Worker.consume conn queue
  print (m, m1, m2, m3, m4, m5)
  Worker.waitAndConsume conn queue $ \m6 -> do
    print m6

  -- interleaving? Multiple connections?
  -- Worker.withChannel conn $ \chan ->
  --   publishMsg chan "myExchange" "myQueue"
  --       newMsg {msgBody = (BL.pack "hello world"),
  --               msgDeliveryMode = Just Persistent}

  -- -- Worker.publish conn queue (TestMessage "henry")
  -- -- Worker.publish conn queue (TestMessage "fat")
  -- Worker.disconnect conn
  -- -- I need to close the connection, or it won't send
  asdf <- getLine
  -- Worker.disconnect conn
  -- print conn
  putStrLn "HELLO"


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
