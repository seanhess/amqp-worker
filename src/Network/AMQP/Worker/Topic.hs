{-# LANGUAGE OverloadedStrings #-}
module Network.AMQP.Worker.Topic where


-- import Network.AMQP.Worker.Key (Binding(..), Key(..), BindingName)









-- you always start out with a single name, like: "messages"
-- and define the type for that topic
-- data Topic msg =
--   Topic (Key Binding)
--   deriving (Show, Eq)


-- topic :: BindingName -> Topic msg
-- topic n = Topic (Key [Name n])



-- (<.>) :: Topic msg -> Binding -> Topic msg
-- (Topic (Key k)) <.> b = Topic $ Key (k ++ [b])



-- type Account = ()


-- accounts :: Topic Account
-- accounts = topic "accounts"


-- but this is actually a "queue". It's a direct message.
-- because you shouldn't be able to publish to anything that has a star in it
-- only things that are concrete
-- so you start with a Direct queue, you can publish to that shit
-- if you keep adding name segments, you can keep working with routing keys
-- but you can make a sub-thing, a topic, which you can subscribe to, but not publish to
-- you can subscribe to either one


-- what is that called?
-- it's not a queue, that's where things end up
-- it's a routing key


-- RoutingKey + Message Type = XXX
-- publisher
-- well, a topic is a pretty good name
-- you can publish and subscribe to topics
-- but an EVENT makes it more general
-- a Subscription is more general

-- Topic = Concrete
-- Subscription = Not concrete
-- Queues are an implementation detail and it'll be confusing

-- Topic -> Topic = Direct (You use the send method)
-- Topic -> Subscription = Event

-- whenever you publish, you publish to a Topic, which is a concrete thing with a specific routing key (no stars) (Routing -> Routing, Routing -> Bdingin, but Binding X-> Routing)

-- when you create a worker, you listen to a Topic or to a Subscription
-- worker: listen to a topic
-- subscribe: listen to a subscription


-- but when you publish to a topic, with the intention that somneone pick it up, you'd like it to be durable no? Guarantee that it's been created?? Maybe not... I mean, it's not my job to make sure that exists, is it?
-- well, I can decide it should exist for sure by simply calling createQueue manually.
-- Otherwise, it'll get created when the subscriber plugs in



-- accountsNew :: Topic Account
-- accountsNew = accounts <.> "new"

-- accountsNew2 :: Topic Account
-- accountsNew2 = accounts <.> Star


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

