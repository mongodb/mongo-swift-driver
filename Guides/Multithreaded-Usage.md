# Using MongoSwift in Mulithreaded Applications

As of MongoSwift 0.2.0, `MongoClient`s are safe to use across threads.
Each `MongoClient` is backed by a pool of server connections, which are used for any server interaction done by the client or one of its child `MongoDatabase` or `MongoCollection`s.
Every `MongoClient` you create will start a background thread in order to monitor the MongoDB topology you are connected to. **In order to minimize the number of these background threads, we recommend sharing `MongoClient`s across threads.**

`MongoDatabase`s and `MongoCollection`s have no mutable state, and store references to their parent `MongoClient`s. Any operation performed on one of these objects will use a connection from its parent client's pool. 

There is no performance benefit to sharing `MongoDatabase`s and `MongoCollection`s across threads if you are already sharing the parent clients across threads, but it is perfectly safe to do so.