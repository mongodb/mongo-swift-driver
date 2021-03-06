import Leaf
import MongoDBVapor
import Vapor

/// Configures the application.
public func configure(_ app: Application) throws {
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Use LeafRenderer for views.
    app.views.use(.leaf)

    // Use `ExtendedJSONEncoder` and `ExtendedJSONDecoder` for encoding/decoding `Content`.
    ContentConfiguration.global.use(encoder: ExtendedJSONEncoder(), for: .json)
    ContentConfiguration.global.use(decoder: ExtendedJSONDecoder(), for: .json)

    // register routes
    try webRoutes(app)
    try restAPIRoutes(app)
}
