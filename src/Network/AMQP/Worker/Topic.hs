{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Topic where


import Network.AMQP.Worker.Key (Binding(..), Key(..), BindingName)





-- you always start out with a single name, like: "messages"
-- and define the type for that topic
data Topic msg =
  Topic (Key Binding)
  deriving (Show, Eq)


topic :: BindingName -> Topic msg
topic n = Topic (Key [Name n])



(<.>) :: Topic msg -> Binding -> Topic msg
(Topic (Key k)) <.> b = Topic $ Key (k ++ [b])



type Account = ()


accounts :: Topic Account
accounts = topic "accounts"


accountsNew :: Topic Account
accountsNew = accounts <.> "new"

accountsNew2 :: Topic Account
accountsNew2 = accounts <.> Star


-- now you can subscribe to topics totally differently from queues
-- subscribe (requires a topic)
-- publish (requires a topic)
-- send (requres a queue)
-- worker (requires a queue) -- although subscribe and worker are the same function. They both initialize things the same way





-- | Publish. Queues support direct messaging: messages go to a queue with a specific name, where they persist until a worker consumes them. 
--
-- > queue :: Queue "testQueue" MyMessageType
-- > queue = Worker.queue exchange "testQueue"

-- well, wait, you don't declare them, do you?
-- ummm....
-- k, this is weird
-- how do I enforce that certain keys represent certain types?


-- basically: RoutingKey
-- basically: BindingKey


-- how can I know that they match? I can't. 
-- can I say anything on this channel is of type Message?
-- I could say that Keys have a type.
-- but the keys don't even match


-- publish: accounts.new
-- subscribe: accounts.*

-- Do I know that they have the same type?
-- not even a little bit
-- I mean, it seems like a "Topic" should have the same message type.
-- but, no, it'll have different data depending on what type it is, of course
-- unless... you assume it's of type Account and it has or hasn't the info it needs
-- I need a real use case
-- but yeah a "Topic"



-- queue :: Key Routing -> Queue msg
-- queue key = Queue key



-- data Queue msg =
--   Queue (Key Routing)
--   deriving (Show, Eq)

