### Version 1.0.0

Major simplification of queues and keys. Users no longer have to think about topic vs direct queues.

* Creating queues automatically binds them
* Keys can be used intuitively to control direct receipt, fanout, and load balancing

### Version 0.4.0

* removed MonadBaseControl following Data.Pool, other internal Data.Pool updates
* updated to GHC 9.2 compat
