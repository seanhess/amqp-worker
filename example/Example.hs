{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent (forkIO)
import Data.Aeson (FromJSON, ToJSON)
import Data.Function ((&))
import Data.Text (Text)
import GHC.Generics (Generic)
import Network.AMQP.Worker
import qualified Network.AMQP.Worker as Worker
import System.IO (BufferMode (..), hSetBuffering, stderr, stdout)

newtype Greeting = Greeting
    {message :: Text}
    deriving (Generic, Show, Eq)

instance FromJSON Greeting
instance ToJSON Greeting

newGreetings :: Key Route Greeting
newGreetings = key "greetings" & word "new"

anyGreetings :: Key Bind Greeting
anyGreetings = key "greetings" & any1

example :: IO ()
example = do
    conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
    simple conn

publishing :: Connection -> IO ()
publishing conn = do
    Worker.publish conn newGreetings $ Greeting "Hello"

-- | Create a queue to process messages
simple :: Connection -> IO ()
simple conn = do
    -- create a queue to receive them
    q <- Worker.queue conn def newGreetings

    -- publish a message (delivered to queue)
    Worker.publish conn newGreetings $ Greeting "Hello"

    -- wait until we receive the message
    m <- Worker.takeMessage conn q
    print (value m)

-- | Multiple queues with distinct names will each get copies of published messages
multiple :: Connection -> IO ()
multiple conn = do
    -- create two separate queues
    one <- Worker.queue conn "one" newGreetings
    two <- Worker.queue conn "two" newGreetings

    -- publish a message (delivered to both)
    Worker.publish conn newGreetings $ Greeting "Hello"

    -- Each of these queues will receive the same message
    m1 <- Worker.takeMessage conn one
    m2 <- Worker.takeMessage conn two

    print $ value m1
    print $ value m2

-- | Create workers to continually process messages
workers :: Connection -> IO ()
workers conn = do
    -- create a single queue
    q <- Worker.queue conn def newGreetings

    -- publish some messages
    Worker.publish conn newGreetings $ Greeting "Hello1"
    Worker.publish conn newGreetings $ Greeting "Hello2"
    Worker.publish conn newGreetings $ Greeting "Hello3"

    -- Create a worker to process any messages on the queue
    _ <- forkIO $ Worker.worker conn q $ \m -> do
        putStrLn "one"
        print (value m)

    -- Listening to the same queue with N workers will load balance them
    _ <- forkIO $ Worker.worker conn q $ \m -> do
        putStrLn "two"
        print (value m)

    putStrLn "Press any key to exit"
    _ <- getLine
    return ()

-- | You can bind to messages dynamically with wildcards in Binding Keys
dynamic :: Connection -> IO ()
dynamic conn = do
    -- anyGreetings matches `greetings.*`
    q <- Worker.queue conn def anyGreetings

    -- You can only publish to a specific Routing Key, like `greetings.new`
    Worker.publish conn newGreetings $ Greeting "Hello"

    -- We cannot publish to anyGreetings because it is a Binding Key (with wildcards in it)
    -- Worker.publish conn anyGreetings $ Greeting "Compiler Error"

    m <- Worker.takeMessage conn q
    print $ value m

test :: (Connection -> IO ()) -> IO ()
test action = do
    hSetBuffering stdout LineBuffering
    hSetBuffering stderr LineBuffering
    conn <- Worker.connect (fromURI "amqp://guest:guest@localhost:5672")
    action conn

main :: IO ()
main = example
