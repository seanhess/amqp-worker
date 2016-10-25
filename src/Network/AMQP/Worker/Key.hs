{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Key
  ( QueueKey(..)
  , RoutingKey(..)
  , BindingKey(..)
  , BindingName(..)
  ) where

import qualified Data.List as List
import qualified Data.List.Split as List
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text

-- | A name used to address queues
newtype RoutingKey = RoutingKey Text
  deriving (Show, Eq)

instance IsString RoutingKey where
  fromString = RoutingKey . Text.pack

instance QueueKey RoutingKey where
  showKey (RoutingKey t) = t


-- | A dynamic binding address for topic queues
--
-- > commentsKey :: BindingKey
-- > commentsKey = "posts.*.comments"
newtype BindingKey = BindingKey [BindingName]
  deriving (Eq)

instance QueueKey BindingKey where
  showKey (BindingKey ns) =
    Text.intercalate "." . List.map bindingNameText $ ns

instance IsString BindingKey where
  fromString s =
    let segments = List.splitOn "." s
        names = List.map fromString segments
    in BindingKey names


data BindingName
  = Name Text
  | Star
  | Hash
  deriving (Eq)

instance IsString BindingName where
  fromString "*" = Star
  fromString "#" = Hash
  fromString n = Name (Text.pack n)

bindingNameText :: BindingName -> Text
bindingNameText (Name t) = t
bindingNameText Star = "*"
bindingNameText Hash = "#"


class QueueKey key where
  showKey :: key -> Text
