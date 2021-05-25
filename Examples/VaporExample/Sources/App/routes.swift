import MongoDBVapor
import Vapor

/// Adds a collection of web routes to the application.
func webRoutes(_ app: Application) throws {
    /// Handles a request to load the main index page containing a list of kittens.
    app.get { req -> EventLoopFuture<View> in
        req.findKittens().flatMap { kittens in
            // Return the corresponding Leaf view, providing the list of kittens as context.
            req.view.render("index.leaf", ["kittens": kittens])
        }
    }

    /// Handles a request to load a page with info about a particular kitten.
    app.get("kittens", ":name") { req -> EventLoopFuture<View> in
        try req.findKitten().flatMap { kitten in
            // Return the corresponding Leaf view, providing the kitten as context.
            req.view.render("kitten.leaf", kitten)
        }
    }
}

// Adds a collection of rest API routes to the application.
func restAPIRoutes(_ app: Application) throws {
    let rest = app.grouped("rest")

    /// Handles a request to load the list of kittens.
    rest.get { req -> EventLoopFuture<[Kitten]> in
        req.findKittens()
    }

    /// Handles a request to add a new kitten.
    rest.post { req -> EventLoopFuture<Response> in
        try req.addKitten()
    }

    /// Handles a request to load info about a particular kitten.
    rest.get("kittens", ":name") { req -> EventLoopFuture<Kitten> in
        try req.findKitten()
    }

    rest.delete("kittens", ":name") { req -> EventLoopFuture<Response> in
        try req.deleteKitten()
    }

    rest.patch("kittens", ":name") { req -> EventLoopFuture<Response> in
        try req.updateKitten()
    }
}

extension Request {
    /// Convenience extension for obtaining a collection which uses the same event loop as a request.
    var kittenCollection: MongoCollection<Kitten> {
        self.mongoDB.client.db("home").collection("kittens", withType: Kitten.self)
    }

    /// Constructs a document using the name from this request which can be used a filter for MongoDB
    /// reads/updates/deletions.
    func getNameFilter() throws -> BSONDocument {
        // We only call this method from request handlers that have name parameters so the value
        // will always be available.
        guard let name = self.parameters.get("name") else {
            throw Abort(.internalServerError, reason: "Request unexpectedly missing name parameter")
        }
        return ["name": .string(name)]
    }

    func findKittens() -> EventLoopFuture<[Kitten]> {
        self.kittenCollection.find().flatMap { cursor in
            cursor.toArray()
        }.flatMapErrorThrowing { error in
            throw Abort(.internalServerError, reason: "Failed to load kittens: \(error)")
        }
    }

    func findKitten() throws -> EventLoopFuture<Kitten> {
        let nameFilter = try self.getNameFilter()
        return self.kittenCollection.findOne(nameFilter)
            .unwrap(or: Abort(.notFound, reason: "No kitten with matching name"))
    }

    func addKitten() throws -> EventLoopFuture<Response> {
        let newKitten = try self.content.decode(Kitten.self)
        return self.kittenCollection.insertOne(newKitten)
            .map { _ in Response(status: .created) }
            .flatMapErrorThrowing { error in
                // Give a more helpful error message in case of a duplicate key error.
                if let err = error as? MongoError.WriteError, err.writeFailure?.code == 11000 {
                    throw Abort(.conflict, reason: "A kitten with the name \(newKitten.name) already exists!")
                }
                throw Abort(.internalServerError, reason: "Failed to save new kitten: \(error)")
            }
    }

    func deleteKitten() throws -> EventLoopFuture<Response> {
        let nameFilter = try self.getNameFilter()
        return self.kittenCollection.deleteOne(nameFilter)
            .flatMapErrorThrowing { error in
                throw Abort(.internalServerError, reason: "Failed to delete kitten: \(error)")
            }
            // since we are not using an unacknowledged write concern we can expect deleteOne to return
            // a non-nil result.
            .unwrap(or: Abort(.internalServerError, reason: "Unexpectedly nil response from database"))
            .flatMapThrowing { result in
                guard result.deletedCount == 1 else {
                    throw Abort(.notFound, reason: "No kitten with matching name")
                }
                return Response(status: .ok)
            }
    }

    func updateKitten() throws -> EventLoopFuture<Response> {
        let nameFilter = try self.getNameFilter()
        // Parse the update data from the request.
        let update = try self.content.decode(KittenUpdate.self)
        /// Create a document using MongoDB update syntax that specifies we want to set a field.
        let updateDocument: BSONDocument = ["$set": .document(try BSONEncoder().encode(update))]

        return self.kittenCollection.updateOne(filter: nameFilter, update: updateDocument)
            .flatMapErrorThrowing { error in
                throw Abort(.internalServerError, reason: "Failed to update kitten: \(error)")
            }
            // since we are not using an unacknowledged write concern we can expect updateOne to return
            // a non-nil result.
            .unwrap(or: Abort(.internalServerError, reason: "Unexpectedly nil response from database"))
            .flatMapThrowing { result in
                guard result.matchedCount == 1 else {
                    throw Abort(.notFound, reason: "No kitten with matching name")
                }
                return Response(status: .ok)
            }
    }
}
