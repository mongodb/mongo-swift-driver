import App
import MongoSwift
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
try configure(app)

defer {
    // shut down the client and clean up the driver's global resources.
    do {
        try app.mongoClient.syncClose()
    } catch {
        app.logger.error("Failed to close MongoClient: \(error)")
    }
    // one-time cleanup code to be run when your application is shutting down.
    cleanupMongoSwift()
    app.shutdown()
}

try app.run()
