import Leaf
import MongoDBVapor
import Vapor

/// Configures the application.
public func configure(_ app: Application) throws {
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Use LeafRenderer for views.
    app.views.use(.leaf)

    // register routes
    try webRoutes(app)
    try restAPIRoutes(app)
}
