{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

-- |
--
-- High level functions for working with message queues. Built on top of Network.AMQP. See https://hackage.haskell.org/package/amqp, which only works with RabbitMQ: https://www.rabbitmq.com/
--
-- /Example/:
--
-- Connect to a server, initialize a queue, publish a message, and create a worker to process them.
--
-- >
-- > {-# LANGUAGE OverloadedStrings #-}
-- > {-# LANGUAGE DeriveGeneric #-}
-- > module Main where
-- >
-- > import Control.Monad.Catch (SomeException)
-- > import Data.Aeson (FromJSON, ToJSON)
-- > import Data.Text (Text)
-- > import GHC.Generics (Generic)
-- > import qualified Network.AMQP.Worker as Worker
-- > import Network.AMQP.Worker (fromURI, Exchange, Queue, Direct, def, WorkerException, Message(..), Connection)
-- >
-- > data TestMessage = TestMessage
-- >  { greeting :: Text }
-- >  deriving (Generic, Show, Eq)
-- >
-- > instance FromJSON TestMessage
-- > instance ToJSON TestMessage
-- >
-- >
-- > exchange :: Exchange
-- > exchange = Worker.exchange "testExchange"
-- >
-- >
-- > queue :: Queue Direct TestMessage
-- > queue = Worker.queue exchange "testQueue"
-- >
-- >
-- > results :: Queue Direct Text
-- > results = Worker.queue exchange "resultQueue"
-- >
-- >
-- > example :: IO ()
-- > example = do
-- >   -- connect
-- >   conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- >
-- >   -- initialize the queues
-- >   Worker.initQueue conn queue
-- >   Worker.initQueue conn results
-- >
-- >   -- publish a message
-- >   Worker.publish conn queue (TestMessage "hello world")
-- >
-- >   -- create a worker, the program loops here
-- >   Worker.worker def conn queue onError (onMessage conn)
-- >
-- >
-- > onMessage :: Connection -> Message TestMessage -> IO ()
-- > onMessage conn m = do
-- >   let testMessage = value m
-- >   putStrLn "Got Message"
-- >   print testMessage
-- >   Worker.publish conn results (greeting testMessage)
-- >
-- >
-- > onError :: WorkerException SomeException -> IO ()
-- > onError e = do
-- >   putStrLn "Do something with errors"
-- >   print e

module Network.AMQP.Worker
  (
  -- * Declaring Queues and Exchanges
    exchange
  , ExchangeName
  , queue
  , topicQueue
  , Exchange(..)
  , Queue(..)
  , Direct, Topic

  -- * Connecting
  , Connection
  , connect
  , disconnect
  , AMQP.fromURI

  -- * Initializing exchanges and queues
  , initQueue

  -- * Publishing Messages
  , publish
  , publishToExchange

  -- * Reading Messages
  , consume
  , consumeNext
  , ConsumeResult(..)
  , ParseError(..)
  , Message(..)

  -- * Worker
  , worker
  , WorkerException(..)
  , WorkerOptions(..)
  , Microseconds
  , Default.def

  -- * Routing Keys
  , Key(..)
  , Routing
  , Binding(..)

  ) where

import qualified Data.Default as Default
import qualified Network.AMQP as AMQP

import Network.AMQP.Worker.Key
import Network.AMQP.Worker.Connection
import Network.AMQP.Worker.Queue
import Network.AMQP.Worker.Message
import Network.AMQP.Worker.Worker
