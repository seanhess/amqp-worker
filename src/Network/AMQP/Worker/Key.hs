{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Network.AMQP.Worker.Key
    ( Key (..)
    , Binding (..)
    , BindingWord
    , Routing
    , key
    , word
    , star
    , hash
    , keyText
    , KeySegment (..)
    , bindingKey
    ) where

import qualified Data.List as List
import Data.Text (Text)
import qualified Data.Text as Text

-- | Keys describe routing and binding info for a message
newtype Key a msg = Key [a]
    deriving (Eq, Show, Semigroup, Monoid)

-- | Every message is sent with a specific routing key
--
-- > newCommentKey :: Key Routing Comment
-- > newCommentKey = key "posts" & word "1" & word "comments" & word "new"
newtype Routing = Routing Text
    deriving (Eq, Show)

instance KeySegment Routing where
    toText (Routing s) = s
    fromText = Routing
    toBind (Routing s) = Word s

-- | A dynamic binding address for topic queues
--
-- > commentsKey :: Key Binding Comment
-- > commentsKey = key "posts" & star & word "comments" & hash
data Binding
    = Word BindingWord
    | Star
    | Hash
    deriving (Eq, Show)

instance KeySegment Binding where
    toText (Word t) = t
    toText Star = "*"
    toText Hash = "#"
    fromText = Word
    toBind = id

class KeySegment a where
    toText :: a -> Text
    fromText :: Text -> a
    toBind :: a -> Binding

keyText :: KeySegment a => Key a msg -> Text
keyText (Key ns) =
    Text.intercalate "." . List.map toText $ ns

-- | Convert any key to a binding key
bindingKey :: KeySegment a => Key a msg -> Key Binding msg
bindingKey (Key rs) = Key (map toBind rs)

-- | Match any one word
star :: KeySegment a => Key a msg -> Key Binding msg
star (Key ws) = Key (map toBind ws ++ [Star])

-- | Match any words
hash :: KeySegment a => Key a msg -> Key Binding msg
hash (Key ws) = Key (map toBind ws ++ [Hash])

-- | Match a specific word
word :: KeySegment a => Text -> Key a msg -> Key a msg
word w (Key ws) = Key $ ws ++ [fromText w]

-- | Create a new key
key :: Text -> Key Routing msg
key t = Key [Routing t]

type BindingWord = Text
