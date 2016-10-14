{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
module Main where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import qualified Network.Worker as Worker
import Network.Worker (fromURI, Exchange, Queue, Direct)
import Network.AMQP (publishMsg)

data TestMessage = TestMessage
  { greeting :: Text }
  deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage


exchange :: Exchange
exchange = Worker.exchange "test-exchange"

queue :: Queue Direct TestMessage
queue = Worker.directQueue exchange "grrrr"


main :: IO ()
main = do
  conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
  Worker.initQueue conn queue
  Worker.publishToExchange conn "test-exchange" "test" (TestMessage "LKJLKJ")
  -- Worker.publish conn queue (TestMessage "henry")
  -- Worker.publish conn queue (TestMessage "fat")
  Worker.disconnect conn
  -- I need to close the connection, or it won't send
  asdf <- getLine
  print conn
  putStrLn "HELLO"
