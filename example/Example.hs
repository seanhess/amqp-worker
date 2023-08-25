{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent (forkIO)
import Control.Monad.Catch (SomeException)
import Data.Aeson (FromJSON, ToJSON)
import Data.Function ((&))
import Data.Text (Text, pack)
import GHC.Generics (Generic)
import Network.AMQP.Worker
    ( Connection
    , Message (..)
    , WorkerException
    , def
    , fromURI
    , queueName
    )
import qualified Network.AMQP.Worker as Worker
import Network.AMQP.Worker.Key
import System.IO
    ( BufferMode (..)
    , hSetBuffering
    , stderr
    , stdout
    )

newtype TestMessage = TestMessage
    {greeting :: Text}
    deriving (Generic, Show, Eq)

instance FromJSON TestMessage
instance ToJSON TestMessage

newMessages :: Key TestMessage
newMessages = key "messages" & word "new"

anyMessages :: Key TestMessage
anyMessages = key "messages" & star

results :: Key Text
results = key "results"

example :: IO ()
example = do
    -- connect
    conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")

    -- TODO: document what happens when you use the same name
    -- TODO: document how to create fanouts vs single-consumer
    -- vs load balancing. This supports all use-cases I can think of

    msgq1 <- Worker.queue conn "msg1" newMessages
    msgq2 <- Worker.queue conn "msg2" newMessages

    -- queues with the same name are equivalent

    -- This queue listens for anything under `messages.`
    anyq <- Worker.queue conn def anyMessages
    resq <- Worker.queue conn def results

    putStrLn "Enter a message"
    msg <- getLine

    -- publish a message
    putStrLn "Publishing a message"
    Worker.publish conn newMessages (TestMessage $ pack msg)

    -- Can I make it so you CAN'T define queues with the same name?
    -- we can't just check
    _ <- forkIO $ Worker.worker conn def msgq1 onError (onMessage "msg1" conn)
    _ <- forkIO $ Worker.worker conn def msgq2 onError (onMessage "msg2" conn)
    _ <- forkIO $ Worker.worker conn def anyq onError (onMessage "any" conn)
    _ <- forkIO $ Worker.worker conn def resq onError onResults

    putStrLn "Press any key to exit"
    _ <- getLine
    return ()

onMessage :: String -> Connection -> Message TestMessage -> IO ()
onMessage name conn m = do
    let testMessage = value m
    putStrLn $ name <> " << " <> show testMessage
    Worker.publish conn results (greeting testMessage)

onResults :: Message Text -> IO ()
onResults m = do
    putStrLn $ "res << " <> show (value m)

onError :: WorkerException SomeException -> IO ()
onError e = do
    putStrLn "Do something with errors"
    print e

main :: IO ()
main = do
    hSetBuffering stdout LineBuffering
    hSetBuffering stderr LineBuffering
    example
