{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module:      Network.AMQP.Worker
-- Copyright:   (c) 2023 Sean Hess
-- License:     BSD3
-- Maintainer:  Sean Hess <seanhess@gmail.com>
-- Stability:   experimental
-- Portability: portable
--
-- Type safe and simplified message queues with AMQP. Compatible with RabbitMQ
module Network.AMQP.Worker
    ( -- * How to use this library
      -- $use

      -- * Connecting
      connect
    , AMQP.fromURI
    , Connection

      -- * Binding and Routing Keys
    , Key (..)
    , Bind
    , Route
    , key
    , word
    , any1
    , many

      -- * Sending Messages
    , publish

      -- * Initializing queues
    , queue
    , queueNamed
    , Queue (..)
    , queueName
    , QueueName
    , QueuePrefix (..)

      -- * Messages
    , takeMessage
    , ParseError (..)
    , Message (..)

      -- * Worker
    , worker
    ) where

import qualified Network.AMQP as AMQP

import Network.AMQP.Worker.Connection
import Network.AMQP.Worker.Key
import Network.AMQP.Worker.Message
import Network.AMQP.Worker.Queue

-- $use
--
-- Define keys to identify how messages will be published and what the message type is
--
-- > import Network.AMQP.Worker as Worker
-- >
-- > data Greeting = Greeting
-- >   { message :: Text }
-- >   deriving (Generic, Show, Eq)
-- >
-- > instance FromJSON Greeting
-- > instance ToJSON Greeting
-- >
-- > newGreetings :: Key Routing Greeting
-- > newGreetings = key "greetings" & word "new"
--
-- Connect to AMQP and publish a message
--
-- > conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- > Worker.publish conn newGreetings $ Greeting "hello"
--
-- Create a queue to receive messages. You can bind direclty to the Routing Key to ensure it is delivered once
--
-- > q <- Worker.queue conn "new" newMessages :: IO (Queue Greeting)
-- > m <- Worker.takeMessage conn q
-- > print (value m)
--
-- Define dynamic Routing Keys to receive many kinds of messages
--
-- > let anyMessages = key "messages" & any1
-- > q <- Worker.queue conn "main" anyMessages
-- > m <- Worker.takeMessage conn q
-- > print (value m)
--
-- Create a worker to conintually process messages
--
-- > forkIO $ Worker.worker conn q $ \m -> do
-- >     print (value m)
