{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Network.AMQP.Worker.Key
  ( Key(..)
  , Binding(..)
  , BindingName
  , Routing
  , keyText
  , KeySegment(..)
  , bindingKey
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.List as List
import qualified Data.List.Split as List
import Data.String (IsString(..))



-- | Every message is sent with a period delimited routing key
--
-- > newCommentKey :: Key Routing
-- > newCommentKey = "posts.1.comments.new"
newtype Routing = Routing Text
    deriving (Eq, IsString, Show)

instance KeySegment Routing where
  segmentText (Routing s) = s



newtype Key a msg = Key [a]
  deriving (Eq, Show)


instance IsString a => IsString (Key a msg) where
  fromString s =
    let segments = List.splitOn "." s
        names = List.map fromString segments
    in Key names


keyText :: KeySegment a => Key a msg -> Text
keyText (Key ns) =
    Text.intercalate "." . List.map segmentText $ ns


bindingKey :: Key Routing a -> Key Binding a
bindingKey (Key rs) = Key (map toBind rs)

toBind :: Routing -> Binding
toBind (Routing t) = fromString $ Text.unpack t


class KeySegment a where
    segmentText :: a -> Text


type BindingName = Text

-- | A dynamic binding address for topic queues
--
-- > commentsKey :: Key Binding
-- > commentsKey = "posts.*.comments.*"
data Binding
    = Name BindingName
    | Star
    | Hash
    deriving (Eq, Show)

instance IsString Binding where
    fromString "*" = Star
    fromString "#" = Hash
    fromString n = Name (Text.pack n)

instance KeySegment Binding where
    segmentText (Name t) = t
    segmentText Star = "*"
    segmentText Hash = "#"
