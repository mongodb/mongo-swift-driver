import Leaf
import MongoDBVapor
import Vapor

/// Configures the application.
public func configure(_ app: Application) throws {
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Use LeafRenderer for views.
    app.views.use(.leaf)

    // Use `ExtendedJSONEncoder` and `ExtendedJSONDecoder` for encoding/decoding `Content`. We use extended JSON both
    // here and on the frontend to ensure all MongoDB type information is correctly preserved.
    // See: https://docs.mongodb.com/manual/reference/mongodb-extended-json
    // Note that for _encoding_ content, this encoder only gets used for the REST API methods, since Leaf uses its own
    // custom encoder to encode data for rendering in Leaf views.
    ContentConfiguration.global.use(encoder: ExtendedJSONEncoder(), for: .json)
    ContentConfiguration.global.use(decoder: ExtendedJSONDecoder(), for: .json)

    // register routes
    try webRoutes(app)
    try restAPIRoutes(app)
}
