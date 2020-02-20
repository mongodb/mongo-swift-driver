import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)

defer {
    // shut down the client and clean up the driver's global resources.
    app.mongoClient.syncShutdown()
    cleanupMongoSwift()
    app.shutdown()
}

try configure(app)
try app.run()
