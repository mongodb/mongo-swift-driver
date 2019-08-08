# Using MongoSwift in Mulithreaded Applications

## Threadsafe Types
As of MongoSwift 0.2.0, the following types are safe to use across threads:
* `MongoClient`
* `MongoDatabase`
* `MongoCollection`

*We make no guarantees about the safety of using any other type across threads.*

## Best Practices
Each `MongoClient` is backed by a pool of server connections. Any time a client or one of its child objects (a `MongoDatabase` or `MongoCollection`) makes a request to the database (a `find`, `insertOne`, etc.) a connection will be retrieved from the pool, used to execute the operation, and then returned to the pool when it is finished.

Each `MongoClient` uses its own background thread to monitor the MongoDB topology you are connected to.

**In order to share the connection pool across threads and minimize the number of background monitoring threads, we recommend sharing `MongoClient`s across threads.**

## Usage With Server-side Swift Frameworks
See the [`Examples/`](https://github.com/mongodb/mongo-swift-driver/tree/master/Examples) directory in the driver GitHub repository for examples of how to integrate the driver in multithreaded frameworks.
