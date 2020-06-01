import MongoSwift
import Vapor

/// Constructs a document using the ID from the specified request which can be used a filter
/// for MongoDB reads/updates/deletions.
func getIDFilter(from request: Request) throws -> BSONDocument {
    // We only call this method from request handlers that have _id parameters so the value
    // will always be available.
    guard let idString = request.parameters.get("_id") else {
        throw Abort(.internalServerError, reason: "Request unexpectedly missing _id parameter")
    }
    // If the BSONObjectID constructor throws, the ID is invalid.
    guard let id = try? BSONObjectID(idString) else {
        throw Abort(.notFound, reason: "Invalid ID \(idString)")
    }
    return ["_id": .objectID(id)]
}

/// Adds a collection of routes to the application.
func routes(_ app: Application) throws {
    /// A collection with type `Kitten`. This allows us to directly retrieve instances of
    /// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
    let collection = app.mongoClient.db("home").collection("kittens", withType: Kitten.self)

    /// Handles a request to load the main index page containing a list of kittens.
    app.get { req -> EventLoopFuture<View> in
        collection.find().flatMap { cursor in
            cursor.toArray()
        // Hop to ensure that the final response future happens on the request's event loop.
        }.hop(to: req.eventLoop)
        .flatMap { kittens in
            // Return the corresponding Leaf view, providing the list of kittens as context.
            req.view.render("index.leaf", IndexContext(kittens: kittens))
        }
        .flatMapErrorThrowing { error in
            throw Abort(.internalServerError, reason: "Failed to load kittens: \(error)")
        }
    }

    /// Handles a request to add a new kitten.
    app.post { req -> EventLoopFuture<Response> in
        let newKitten = try req.content.decode(Kitten.self)
        return collection.insertOne(newKitten)
        // Hop to ensure that the final response future happens on the request's event loop.
        .hop(to: req.eventLoop)
        .map { _ in
            // On success, redirect to the index to reload the updated list.
            req.redirect(to: "/")
        }
        .flatMapErrorThrowing { error in
            // Give a more helpful error message in case of a duplicate key error.
            if let err = error as? MongoError.WriteError, err.writeFailure?.code == 11000 {
                throw Abort(.conflict, reason: "A kitten with the name \(newKitten.name) already exists!")
            }
            throw Abort(.internalServerError, reason: "Failed to save new kitten: \(error)")
        }
    }

    /// Handles a request to load info about a particular kitten.
    app.get("kittens", ":_id") { req -> EventLoopFuture<View> in
        let idFilter = try getIDFilter(from: req)
        return collection.findOne(idFilter)
            // Hop to ensure that the final response future happens on the request's event loop.
            .hop(to: req.eventLoop)
            .unwrap(or: Abort(.notFound, reason: "No kitten with matching ID"))
            .flatMap { kitten in
                // Return the corresponding Leaf view, providing the kitten as context.
                req.view.render("kitten.leaf", kitten)
            }
    }

    app.delete("kittens", ":_id") { req -> EventLoopFuture<Response> in
        let idFilter = try getIDFilter(from: req)
        return collection.deleteOne(idFilter)
        // Hop to ensure that the final response future happens on the request's event loop.
        .hop(to: req.eventLoop)
        .flatMapErrorThrowing { error in
            throw Abort(.internalServerError, reason: "Failed to delete kitten: \(error)")
        }
        // since we are not using an unacknowledged write concern we can expect deleteOne to return
        // a non-nil result.
        .unwrap(or: Abort(.internalServerError, reason: "Unexpectedly nil response from database"))
        .flatMapThrowing { result in
            guard result.deletedCount == 1 else {
                throw Abort(.notFound, reason: "No kitten with matching ID")
            }
            return Response(status: .ok)
        }
    }

    app.patch("kittens", ":_id") { req -> EventLoopFuture<Response> in
        let idFilter = try getIDFilter(from: req)
        // Parse the update data from the request.
        let update = try req.content.decode(FoodUpdate.self)
        /// Create a document using MongoDB update syntax that specifies we want to set a field.
        let updateDocument: BSONDocument = ["$set": .document(try BSONEncoder().encode(update))]

        return collection.updateOne(filter: idFilter, update: updateDocument)
        // Hop to ensure that the final response future happens on the request's event loop.
        .hop(to: req.eventLoop)
        .flatMapErrorThrowing { error in
            throw Abort(.internalServerError, reason: "Failed to update kitten: \(error)")
        }
        // since we are not using an unacknowledged write concern we can expect updateOne to return
        // a non-nil result.
        .unwrap(or: Abort(.internalServerError, reason: "Unexpectedly nil response from database"))
        .flatMapThrowing { result in
            guard result.modifiedCount == 1 else {
                throw Abort(.notFound, reason: "No kitten with matching ID")
            }
            return Response(status: .ok)
        }
    }
}
