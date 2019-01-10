{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE ExplicitForAll             #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeFamilies               #-}

module Network.AMQP.Worker.Entity (
  module Network.AMQP.Worker.Entity,
  ExchangeName
)where

import           Control.Monad                              (void)
import           Data.String                                (IsString (..))
import           Data.Text                                  (Text, pack)
import           Lens.Micro                                 (Lens', lens, to,
                                                             (&), (.~), (^.))
import qualified Network.AMQP                               as AMQP
import qualified Network.AMQP.Types                         as AMQP
import           Network.AMQP.Worker.Connection             (Connection,
                                                             withChannel)
import           Network.AMQP.Worker.Entity.ExchangeOptions (ExchangeAutoDelete,
                                                             ExchangeDurable,
                                                             ExchangeName (..),
                                                             ExchangeVisibility)
import qualified Network.AMQP.Worker.Entity.ExchangeOptions as ExchangeOptions

--
-- AMQP Entity Lifecycle types
--
data Defined
data Declared

--
-- AMQP Queues
--

newtype QueueName = QueueName Text deriving (Eq, Ord, Show)

data Queue lifecycle msg where
  QueueDefinition  :: AMQP.QueueOpts -> Queue Defined msg
  Queue            :: Text -> Queue Declared msg

deriving instance Show (Queue lifecycle msg)
deriving instance Eq   (Queue lifecycle msg)

instance IsString (Queue Defined msg) where
  fromString = queue . QueueName . pack

queue :: QueueName -> Queue Defined msg
queue (QueueName name) = QueueDefinition $ AMQP.newQueue { AMQP.queueName = name }

declareQueue :: Connection -> Queue Defined msg -> IO (Queue Declared msg)
declareQueue conn (QueueDefinition queueOpts) =
  withChannel conn $ \chan -> do
    (declaredQueueName, _, _) <- AMQP.declareQueue chan queueOpts
    return $ Queue declaredQueueName

-- | Check for a message once and attempt to parse it
--
-- > res <- consume conn queue
-- > case res of
-- >   Just (Parsed m) -> print m
-- >   Just (Error e) -> putStrLn "could not parse message"
-- >   Notihng -> putStrLn "No messages on the queue"
getMsg :: Connection -> Queue Declared msg -> IO (Maybe (AMQP.Message, AMQP.Envelope))
getMsg conn (Queue queueName) =
  withChannel conn $ \chan ->
    AMQP.getMsg chan AMQP.Ack queueName

--
-- Abstract AMQP Exchanges
--
data Exchange lifecycle exchangeType msg where
  ExchangeDefinition :: { exchangeOpts :: AMQP.ExchangeOpts } -> Exchange Defined exchangeType msg
  Exchange           :: Text -> Exchange Declared exchangeType msg

deriving instance Show (Exchange lifecycle exchangeType msg)
deriving instance Eq   (Exchange lifecycle exchangeType msg)

instance ExchangeType exchangeType => IsString (Exchange Defined exchangeType msg) where
  fromString = exchange . ExchangeName . pack

exchangeOptions :: Lens' (Exchange Defined exchangeType msg) AMQP.ExchangeOpts
exchangeOptions = lens exchangeOpts (const ExchangeDefinition)

exchangeDurable :: Lens' (Exchange Defined exchangeType msg) ExchangeOptions.ExchangeDurable
exchangeDurable = exchangeOptions . ExchangeOptions.exchangeDurable

exchangeAutoDelete :: Lens' (Exchange Defined exchangeType msg) ExchangeOptions.ExchangeAutoDelete
exchangeAutoDelete = exchangeOptions . ExchangeOptions.exchangeAutoDelete

exchangeVisibility :: Lens' (Exchange Defined exchangeType msg) ExchangeOptions.ExchangeVisibility
exchangeVisibility = exchangeOptions . ExchangeOptions.exchangeVisibility


class ExchangeType exchangeType where
  type RoutingKey exchangeType

  exchangeType :: Text

  exchange :: ExchangeName -> Exchange Defined exchangeType msg
  exchange exchname =
    ExchangeDefinition $
      AMQP.newExchange { AMQP.exchangeType = exchangeType @exchangeType }
        & ExchangeOptions.exchangeName .~ exchname

  bindQueue :: Connection -> Exchange Declared exchangeType msg -> Queue Declared msg -> RoutingKey exchangeType -> IO ()
  bindQueue conn exc queue key = withChannel conn $ \chan -> doBindQueue chan exc queue key

  putMsg :: Connection -> Exchange Declared exchangeType msg -> RoutingKey exchangeType -> AMQP.Message -> IO ()
  putMsg conn exc key msg = withChannel conn $ \chan -> doPutMsg chan exc key msg

  doBindQueue :: AMQP.Channel -> Exchange Declared exchangeType msg -> Queue Declared msg -> RoutingKey exchangeType -> IO ()
  doPutMsg :: AMQP.Channel -> Exchange Declared exchangeType msg -> RoutingKey exchangeType -> AMQP.Message -> IO ()

declareExchange :: ExchangeType exchangeType => Connection -> Exchange Defined exchangeType msg -> IO (Exchange Declared exchangeType msg)
declareExchange conn (ExchangeDefinition exchangeOpts) =
  withChannel conn $ \chan -> do
    AMQP.declareExchange chan exchangeOpts
    return (Exchange $ AMQP.exchangeName exchangeOpts)


--
-- Concrete AMQP Exchanges
--

data Direct

newtype FlatRoutingKey = FlatRoutingKey Text deriving (Eq, Ord, Show, Read, IsString)

instance ExchangeType Direct where
  type RoutingKey Direct = FlatRoutingKey

  exchangeType = "direct"

  doBindQueue chan (Exchange exchangeName) (Queue queueName) (FlatRoutingKey key) =
    AMQP.bindQueue chan queueName exchangeName key

  doPutMsg chan (Exchange exchangeName) (FlatRoutingKey key) msg =
    void $ AMQP.publishMsg chan exchangeName key msg



data Fanout

instance ExchangeType Fanout where
  type RoutingKey Fanout = ()

  exchangeType = "fanout"

  doBindQueue chan (Exchange exchangeName) (Queue queueName) () =
    AMQP.bindQueue chan queueName exchangeName ""

  doPutMsg chan (Exchange exchangeName) () msg =
    void $ AMQP.publishMsg chan exchangeName "" msg

data Topic

instance ExchangeType Topic where
  type RoutingKey Topic = FlatRoutingKey

  exchangeType = "topic"

  doBindQueue chan (Exchange exchangeName) (Queue queueName) (FlatRoutingKey key) =
    AMQP.bindQueue chan queueName exchangeName key

  doPutMsg chan (Exchange exchangeName) (FlatRoutingKey key) msg =
    void $ AMQP.publishMsg chan exchangeName key msg

--
-- Utility functions
--
initQueue :: ExchangeType exchangeType => Connection -> Exchange Defined exchangeType msg -> Queue Defined msg -> RoutingKey exchangeType -> IO (Queue Declared msg)
initQueue conn exchange queue key = do
  declaredExchange <- declareExchange conn exchange
  declaredQueue    <- declareQueue conn queue

  bindQueue conn declaredExchange declaredQueue key

  return declaredQueue
