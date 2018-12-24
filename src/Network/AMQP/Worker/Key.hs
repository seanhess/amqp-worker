{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Network.AMQP.Worker.Key
  ( Key(..)
  , Binding(..)
  , BindingWord
  , Routing
  , key
  , word, star, hash
  , keyText
  , KeySegment(..)
  , bindingKey
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.List as List



-- | Every message is sent with a period delimited routing key
--
-- > newCommentKey :: Key Routing
-- > newCommentKey = "posts.1.comments.new"
newtype Routing = Routing Text
    deriving (Eq, Show)

-- instance IsString Routing where
--   fromString "*" = error "routing keys cannot contain * or #"
--   fromString "#" = error "routing keys cannot contain * or #"
--   fromString n = Routing $ Text.pack n

instance KeySegment Routing where
  toText (Routing s) = s
  fromText = Routing
  toBind (Routing s) = Word s



newtype Key a msg = Key [a]
  deriving (Eq, Show, Semigroup, Monoid)


-- instance IsString a => IsString (Key a msg) where
--   fromString s =
--     let segments = List.splitOn "." s
--         names = List.map fromString segments
--     in Key names



keyText :: KeySegment a => Key a msg -> Text
keyText (Key ns) =
    Text.intercalate "." . List.map toText $ ns


bindingKey :: KeySegment a => Key a msg -> Key Binding msg
bindingKey (Key rs) = Key (map toBind rs)



star :: KeySegment a => Key a msg -> Key Binding msg
star (Key ws) = Key (map toBind ws ++ [Star])

hash :: KeySegment a => Key a msg -> Key Binding msg
hash (Key ws) = Key (map toBind ws ++ [Hash])

word :: KeySegment a => Text -> Key a msg -> Key a msg
word w (Key ws) = Key $ ws ++ [fromText w]


-- you can't convert from Binding to Routing
-- (<.>) :: Key a msg -> a -> Key a msg
-- (Key as) <.> a = Key (as <> [a])


-- I need to specity that Routing -> Binding -> Binding
-- Binding -> Binding -> Binding
-- Routing -> Binding -> Binding
-- Routing -> Routing -> Routing

-- with a type family, I think?


key :: Text -> Key Routing msg
key t = Key [Routing t]




-- well I want to do something different when it's combined with itself
-- R + B = B
-- bassicaly if it's two Routing then key Routing
-- there's a special case in the Routing class

class KeySegment a where
    -- type Combined a :: *
    -- combine :: a -> Combined a
    toText   :: a -> Text
    fromText :: Text -> a
    toBind :: a -> Binding


type BindingWord = Text

-- | A dynamic binding address for topic queues
--
-- > commentsKey :: Key Binding
-- > commentsKey = "posts.*.comments.*"
data Binding
    = Word BindingWord
    | Star
    | Hash
    deriving (Eq, Show)

-- instance IsString Binding where
--     fromString "*" = Star
--     fromString "#" = Hash
--     fromString n = Word (Text.pack n)

instance KeySegment Binding where
    toText (Word t) = t
    toText Star = "*"
    toText Hash = "#"
    fromText = Word
    toBind = id
