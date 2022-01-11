import MongoDBVapor
import Vapor

/// Adds a collection of web routes to the application.
func webRoutes(_ app: Application) throws {
    /// Handles a request to load the main index page containing a list of kittens.
    app.get { req async throws -> View in
        let kittens = try await req.findKittens()
        // Return the corresponding Leaf view, providing the list of kittens as context.
        return try await req.view.render("index.leaf", ["kittens": kittens])
    }

    /// Handles a request to load a page with info about a particular kitten.
    app.get("kittens", ":name") { req async throws -> View in
        let kitten = try await req.findKitten()
        // Return the corresponding Leaf view, providing the kitten as context.
        return try await req.view.render("kitten.leaf", kitten)
    }
}

// Adds a collection of rest API routes to the application.
func restAPIRoutes(_ app: Application) throws {
    let rest = app.grouped("rest")

    /// Handles a request to load the list of kittens.
    rest.get { req async throws -> [Kitten] in
        try await req.findKittens()
    }

    /// Handles a request to add a new kitten.
    rest.post { req async throws -> Response in
        try await req.addKitten()
    }

    /// Handles a request to load info about a particular kitten.
    rest.get("kittens", ":name") { req async throws -> Kitten in
        try await req.findKitten()
    }

    rest.delete("kittens", ":name") { req async throws -> Response in
        try await req.deleteKitten()
    }

    rest.patch("kittens", ":name") { req async throws -> Response in
        try await req.updateKitten()
    }
}

extension Request {
    /// Convenience extension for obtaining a collection.
    var kittenCollection: MongoCollection<Kitten> {
        self.application.mongoDB.client.db("home").collection("kittens", withType: Kitten.self)
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

    func findKittens() async throws -> [Kitten] {
        do {
            return try await self.kittenCollection.find().toArray()
        } catch {
            throw Abort(.internalServerError, reason: "Failed to load kittens: \(error)")
        }
    }

    func findKitten() async throws -> Kitten {
        let nameFilter = try self.getNameFilter()
        guard let kitten = try await self.kittenCollection.findOne(nameFilter) else {
            throw Abort(.notFound, reason: "No kitten with matching name")
        }
        return kitten
    }

    func addKitten() async throws -> Response {
        let newKitten = try self.content.decode(Kitten.self)
        do {
            try await self.kittenCollection.insertOne(newKitten)
            return Response(status: .created)
        } catch {
            // Give a more helpful error message in case of a duplicate key error.
            if let err = error as? MongoError.WriteError, err.writeFailure?.code == 11000 {
                throw Abort(.conflict, reason: "A kitten with the name \(newKitten.name) already exists!")
            }
            throw Abort(.internalServerError, reason: "Failed to save new kitten: \(error)")
        }
    }

    func deleteKitten() async throws -> Response {
        let nameFilter = try self.getNameFilter()
        do {
            // since we aren't using an unacknowledged write concern we can expect deleteOne to return a non-nil result.
            guard let result = try await self.kittenCollection.deleteOne(nameFilter) else {
                throw Abort(.internalServerError, reason: "Unexpectedly nil response from database")
            }
            guard result.deletedCount == 1 else {
                throw Abort(.notFound, reason: "No kitten with matching name")
            }
            return Response(status: .ok)
        } catch {
            throw Abort(.internalServerError, reason: "Failed to delete kitten: \(error)")
        }
    }

    func updateKitten() async throws -> Response {
        let nameFilter = try self.getNameFilter()
        // Parse the update data from the request.
        let update = try self.content.decode(KittenUpdate.self)
        /// Create a document using MongoDB update syntax that specifies we want to set a field.
        let updateDocument: BSONDocument = ["$set": .document(try BSONEncoder().encode(update))]

        do {
            // since we aren't using an unacknowledged write concern we can expect updateOne to return a non-nil result.
            guard let result = try await self.kittenCollection.updateOne(
                filter: nameFilter,
                update: updateDocument
            ) else {
                throw Abort(.internalServerError, reason: "Unexpectedly nil response from database")
            }
            guard result.matchedCount == 1 else {
                throw Abort(.notFound, reason: "No kitten with matching name")
            }
            return Response(status: .ok)
        } catch {
            throw Abort(.internalServerError, reason: "Failed to update kitten: \(error)")
        }
    }
}
