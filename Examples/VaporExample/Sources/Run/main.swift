import App
import MongoDBVapor
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
try configure(app)
try app.mongoDB.configure("mongodb://localhost:27017")

defer {
    app.mongoDB.cleanup()
    // one-time cleanup code to be run when your application is shutting down.
    cleanupMongoSwift()
    app.shutdown()
}

try app.run()
