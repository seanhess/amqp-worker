{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Network.AMQP.Worker.Entity.ExchangeOptions where

import           Data.String        (IsString (..))
import           Data.Text          (Text)
import           Lens.Micro         (Lens', lens, to, (&), (.~), (^.))
import qualified Network.AMQP       as AMQP
import qualified Network.AMQP.Types as AMQP


class BinaryChoice choice where
  toBool :: choice -> Bool
  fromBool :: Bool -> choice

newtype ExchangeName       = ExchangeName Text deriving (Eq, Ord, Show, IsString)
data    ExchangeDurable    = Durable | Transient deriving (Eq, Ord, Show)
data    ExchangeAutoDelete = Autodelete | NonAutodelete deriving (Eq, Ord, Show)
data    ExchangeVisibility = Internal | External deriving (Eq, Ord, Show)

instance BinaryChoice ExchangeDurable where
  toBool Durable   = True
  toBool Transient = False

  fromBool True  = Durable
  fromBool False = Transient

instance BinaryChoice ExchangeAutoDelete where
  toBool Autodelete    = True
  toBool NonAutodelete = False

  fromBool True  = Autodelete
  fromBool False = NonAutodelete

instance BinaryChoice ExchangeVisibility where
  toBool Internal = True
  toBool External = False

  fromBool True  = Internal
  fromBool False = External


exchangeName :: Lens' AMQP.ExchangeOpts ExchangeName
exchangeName =
  lens
    (ExchangeName . AMQP.exchangeName)
    (\old (ExchangeName newName) -> old { AMQP.exchangeName = newName })

exchangeDurable :: Lens' AMQP.ExchangeOpts ExchangeDurable
exchangeDurable =
  lens
    (fromBool . AMQP.exchangeDurable)
    (\old new -> old { AMQP.exchangeDurable = toBool new })

exchangeAutoDelete :: Lens' AMQP.ExchangeOpts ExchangeAutoDelete
exchangeAutoDelete =
  lens
    (fromBool . AMQP.exchangeAutoDelete)
    (\old new -> old { AMQP.exchangeAutoDelete = toBool new })

exchangeVisibility :: Lens' AMQP.ExchangeOpts ExchangeVisibility
exchangeVisibility =
  lens
    (fromBool . AMQP.exchangeInternal)
    (\old new -> old { AMQP.exchangeInternal = toBool new })
