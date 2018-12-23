{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Exchange where

import Data.Text (Text)

type ExchangeName = Text


-- | Declare an exchange
--
-- In AMQP, exchanges can be fanout, direct, or topic. This library attempts to simplify this choice by making all exchanges be topic exchanges, and allowing the user to specify topic or direct behavior on the queue itself. See @queue@
--
-- > exchange :: Exchange
-- > exchange = Worker.exchange "testExchange"

exchange :: ExchangeName -> Exchange
exchange nm = Exchange nm



newtype Exchange = Exchange ExchangeName
  deriving (Show, Eq)

