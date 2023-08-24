{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Network.AMQP.Worker.Key
    ( Key (..)
    , Binding (..)
    , BindingWord
    , key
    , word
    , star
    , hash
    , keyText
    , fromBind
    , toBind
    ) where

import qualified Data.List as List
import Data.Text (Text)
import qualified Data.Text as Text

-- | Keys describe routing and binding info for a message
newtype Key msg = Key [Binding]
    deriving (Eq, Show, Semigroup, Monoid)

-- | A dynamic binding address for topic queues
--
-- > commentsKey :: Key Binding Comment
-- > commentsKey = key "posts" & star & word "comments" & hash
data Binding
    = Word BindingWord
    | Star
    | Hash
    deriving (Eq, Show)

fromBind :: Binding -> Text
fromBind (Word t) = t
fromBind Star = "*"
fromBind Hash = "#"

toBind :: Text -> Binding
toBind = Word

keyText :: Key msg -> Text
keyText (Key ns) =
    Text.intercalate "." . List.map fromBind $ ns

-- | Match any one word
star :: Key msg -> Key msg
star (Key ws) = Key (ws ++ [Star])

-- | Match any words
hash :: Key msg -> Key msg
hash (Key ws) = Key (ws ++ [Hash])

-- | Match a specific word
word :: Text -> Key msg -> Key msg
word w (Key ws) = Key $ ws ++ [toBind w]

-- | Create a new key
key :: Text -> Key msg
key t = Key [Word t]

type BindingWord = Text
