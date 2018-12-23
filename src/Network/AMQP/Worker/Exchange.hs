{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Exchange where

import Data.Text (Text)
import qualified Network.AMQP as AMQP
import Network.AMQP (ExchangeOpts(..))

type ExchangeName = Text


-- | Declare an exchange
--
-- In AMQP, exchanges can be fanout, direct, or topic. This library attempts to simplify this choice by making all exchanges be topic exchanges, and allowing the user to specify topic or direct behavior on the queue itself. See @queue@
--
-- > exchange :: Exchange
-- > exchange = Worker.exchange "testExchange"

exchange :: ExchangeName -> Exchange
exchange nm =
  Exchange $ AMQP.newExchange { exchangeName = nm, exchangeType = "topic" }


data Exchange =
  Exchange AMQP.ExchangeOpts
  deriving (Show, Eq)

