{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
--
-- High level functions for working with message queues. Built on top of Network.AMQP. See https://hackage.haskell.org/package/amqp, which only works with RabbitMQ: https://www.rabbitmq.com/
--
-- /Example/:
--
-- Connect to a server, initialize a queue, publish a message, and create a worker to process them.
--
-- > {-# LANGUAGE DeriveGeneric     #-}
-- > {-# LANGUAGE OverloadedStrings #-}
-- > module Main where
-- >
-- > import           Control.Concurrent      (forkIO)
-- > import           Control.Monad.Catch     (SomeException)
-- > import           Data.Aeson              (FromJSON, ToJSON)
-- > import           Data.Function           ((&))
-- > import           Data.Text               (Text, pack)
-- > import           GHC.Generics            (Generic)
-- > import           Network.AMQP.Worker     (Connection, Message (..),
-- >                                           WorkerException, def, fromURI)
-- > import qualified Network.AMQP.Worker     as Worker
-- > import           Network.AMQP.Worker.Key
-- > import           System.IO               (BufferMode (..), hSetBuffering,
-- >                                           stderr, stdout)
-- >
-- > data TestMessage = TestMessage
-- >   { greeting :: Text }
-- >   deriving (Generic, Show, Eq)
-- >
-- > instance FromJSON TestMessage
-- > instance ToJSON TestMessage
-- >
-- >
-- > newMessages :: Key Routing TestMessage
-- > newMessages = key "messages" & word "new"
-- >
-- > results :: Key Routing Text
-- > results = key "results"
-- >
-- > anyMessages :: Key Binding TestMessage
-- > anyMessages = key "messages" & star
-- >
-- >
-- >
-- > example :: IO ()
-- > example = do
-- >
-- >   -- connect
-- >   conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
-- >
-- >   let handleAnyMessages = Worker.topic anyMessages "handleAnyMessage"
-- >
-- >   -- initialize the queues
-- >   Worker.bindQueue conn (Worker.direct newMessages)
-- >   Worker.bindQueue conn (Worker.direct results)
-- >
-- >   -- topic queue!
-- >   Worker.bindQueue conn handleAnyMessages
-- >
-- >   putStrLn "Enter a message"
-- >   msg <- getLine
-- >
-- >   -- publish a message
-- >   putStrLn "Publishing a message"
-- >   Worker.publish conn newMessages (TestMessage $ pack msg)
-- >
-- >   -- create a worker, the program loops here
-- >   _ <- forkIO $ Worker.worker conn def (Worker.direct newMessages) onError (onMessage conn)
-- >   _ <- forkIO $ Worker.worker conn def (handleAnyMessages) onError (onMessage conn)
-- >
-- >   putStrLn "Press any key to exit"
-- >   _ <- getLine
-- >   return ()
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
-- >
-- >
module Network.AMQP.Worker
    ( -- * Routing Keys
      Key (..)
    , Routing
    , Binding
    , word
    , key
    , star
    , hash

      -- * Connecting
    , Connection
    , connect
    , disconnect
    , exchange
    , AMQP.fromURI

      -- * Initializing queues
    , Queue (..)
    , direct
    , topic
    , bindQueue

      -- * Sending Messages
    , publish
    , publishToExchange

      -- * Reading Messages
    , consume
    , consumeNext
    , ConsumeResult (..)
    , ParseError (..)
    , Message (..)

      -- * Worker
    , worker
    , WorkerException (..)
    , WorkerOptions (..)
    , Microseconds
    , Default.def
    ) where

import qualified Data.Default as Default
import qualified Network.AMQP as AMQP

import Network.AMQP.Worker.Connection
import Network.AMQP.Worker.Key
import Network.AMQP.Worker.Message
import Network.AMQP.Worker.Queue
import Network.AMQP.Worker.Worker
