{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent (forkIO)
import Control.Monad.Catch (SomeException)
import Data.Aeson (FromJSON, ToJSON)
import Data.Function ((&))
import Data.Text (Text)
import GHC.Generics (Generic)
import Network.AMQP.Worker
import qualified Network.AMQP.Worker as Worker
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

newMessages :: Key Routing TestMessage
newMessages = key "messages" & word "new"

anyMessages :: Key Binding TestMessage
anyMessages = key "messages" & any1

example :: IO ()
example = do
    conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
    simple conn

publishing :: Connection -> IO ()
publishing conn = do
    Worker.publish conn newMessages $ TestMessage "Hello"

-- | Create a queue to process messages
simple :: Connection -> IO ()
simple conn = do
    -- create a queue to receive them
    q <- Worker.queue conn def newMessages

    -- publish a message (delivered to queue)
    Worker.publish conn newMessages $ TestMessage "Hello"

    -- We cannot publish to anyMessages because it is a binding key (with wildcards in it)
    -- Worker.publish conn anyMessages $ TestMessage "Compiler Error"

    -- Loop and print any values received
    Worker.worker conn def q onError (print . value)

-- | Multiple queues with distinct names will each get copies of published messages
multiple :: Connection -> IO ()
multiple conn = do
    -- create two separate queues
    one <- Worker.queue conn "one" newMessages
    two <- Worker.queue conn "two" newMessages

    -- publish a message (delivered to both)
    Worker.publish conn newMessages $ TestMessage "Hello"

    -- Each of these workers will receive the same message
    _ <- forkIO $ Worker.worker conn def one onError $ \m -> putStrLn "one" >> print (value m)
    _ <- forkIO $ Worker.worker conn def two onError $ \m -> putStrLn "two" >> print (value m)

    putStrLn "Press any key to exit"
    _ <- getLine
    return ()

-- | Create multiple workers on the same queue to load balance between them
balance :: Connection -> IO ()
balance conn = do
    -- create a single queue
    q <- Worker.queue conn def newMessages

    -- publish two messages
    Worker.publish conn newMessages $ TestMessage "Hello1"
    Worker.publish conn newMessages $ TestMessage "Hello2"

    -- Each worker will receive one of the messages
    _ <- forkIO $ Worker.worker conn def q onError $ \m -> putStrLn "one" >> print (value m)
    _ <- forkIO $ Worker.worker conn def q onError $ \m -> putStrLn "two" >> print (value m)

    putStrLn "Press any key to exit"
    _ <- getLine
    return ()

-- | You can bind to messages dynamically with wildcards in Binding Keys
dynamic :: Connection -> IO ()
dynamic conn = do
    -- \| anyMessages matches `messages.*`
    q <- Worker.queue conn def anyMessages

    Worker.publish conn newMessages $ TestMessage "Hello"

    -- This queue listens for anything under `messages.`
    Worker.worker conn def q onError $ \m -> putStrLn "Got: " >> print (value m)

onError :: WorkerException SomeException -> IO ()
onError e = do
    putStrLn "Do something with errors"
    print e

test :: (Connection -> IO ()) -> IO ()
test action = do
    hSetBuffering stdout LineBuffering
    hSetBuffering stderr LineBuffering
    conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
    action conn

main :: IO ()
main = example
