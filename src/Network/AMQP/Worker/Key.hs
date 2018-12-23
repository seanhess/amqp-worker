{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Network.AMQP.Worker.Key
  ( Key(..)
  , Binding(..)
  , Routing
  ) where

import qualified Data.List as List
import qualified Data.List.Split as List
import Data.String (IsString(..))

-- | Every message is sent with a period delimited routing key
--
-- > newCommentKey :: Key Routing
-- > newCommentKey = "posts.1.comments.new"
newtype Routing = Routing String
    deriving (Eq, IsString)

instance Show Routing where
  show (Routing s) = s



newtype Key a = Key [a]
  deriving (Eq)


instance IsString a => IsString (Key a) where
  fromString s =
    let segments = List.splitOn "." s
        names = List.map fromString segments
    in Key names

instance (Show a) => Show (Key a) where
    show (Key ns) =
      List.intercalate "." . List.map show $ ns


-- | A dynamic binding address for topic queues
--
-- > commentsKey :: Key Binding
-- > commentsKey = "posts.*.comments.*"
data Binding
  = Name String
  | Star
  | Hash
  deriving (Eq)

instance IsString Binding where
  fromString "*" = Star
  fromString "#" = Hash
  fromString n = Name n

instance Show Binding where
  show (Name t) = t
  show Star = "*"
  show Hash = "#"
