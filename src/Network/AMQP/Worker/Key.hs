{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Network.AMQP.Worker.Key
    ( Key (..)
    , Binding (..)
    , Routing
    , key
    , word
    , any1
    , many
    , keyText
    , fromBind
    , toBind
    , toBindingKey
    , RequireRouting
    ) where

import Data.Kind (Constraint, Type)
import qualified Data.List as List
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.TypeLits (ErrorMessage (..), TypeError)

-- | Keys describe routing and binding info for a message
newtype Key a msg = Key [Binding]
    deriving (Eq, Show, Semigroup, Monoid)

-- | Routing keys have no dynamic component and can be used to publish messages
data Routing

-- | Binding keys are similar, except used for matching messages. They can contain * and #
--
-- > commentsKey :: Key Binding Comment
-- > commentsKey = key "posts" & any1 & word "comments" & many
data Binding
    = Word Text
    | Any
    | Many
    deriving (Eq, Show)

fromBind :: Binding -> Text
fromBind (Word t) = t
fromBind Any = "*"
fromBind Many = "#"

toBind :: Text -> Binding
toBind = Word

keyText :: Key a msg -> Text
keyText (Key ns) =
    Text.intercalate "." . List.map fromBind $ ns

-- | Match any one word. Equivalent to `*`. Converts to a Binding key and can no longer be used to publish messaages
any1 :: Key a msg -> Key Binding msg
any1 (Key ws) = Key (ws ++ [Any])

-- | Match zero or more words. Equivalient to `#`. Converts to a Binding key and can no longer be used to publish messages
many :: Key a msg -> Key Binding msg
many (Key ws) = Key (ws ++ [Many])

-- | A specific word. Can be used to chain Routing keys or Binding keys
word :: Text -> Key a msg -> Key a msg
word w (Key ws) = Key $ ws ++ [toBind w]

-- | Start a new routing key (can be used for bindings)
key :: Text -> Key Routing msg
key t = Key [Word t]

-- | We can convert Routing Keys to Binding Keys safely, as they are usable for both publishing and binding
toBindingKey :: Key a msg -> Key Binding msg
toBindingKey (Key ws) = Key ws

-- | Custom error message
type family RequireRouting (a :: Type) :: Constraint where
    RequireRouting Binding =
        TypeError
            ( 'Text "Expected Routing Key but got Binding Key instead. Messages can be published only with keys that exclusivlely use `key` and `word`"
                :$$: 'Text "\n          key \"message\" & word \"new\" \n"
            )
    RequireRouting a = ()
