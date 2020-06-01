import App
import MongoSwift
import Vapor

var env = try Environment.detect()
let app = Application(env)
try configure(app)

defer {
    // shut down the client and clean up the driver's global resources.
    try? app.mongoClient.syncClose()
    // one-time cleanup code to be run when your application is shutting down.
    cleanupMongoSwift()
    app.shutdown()
}

try app.run()
