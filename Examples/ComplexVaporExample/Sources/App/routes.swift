import MongoSwift
import Vapor

func routes(_ app: Application) throws {
    /// A collection with type `Kitten`. This allows us to directly retrieve instances of
    /// `Kitten` from the collection.  `MongoCollection` is safe to share across threads.
    let collection = app.mongoClient.db("home").collection("kittens", withType: Kitten.self)

    app.get { req -> EventLoopFuture<[Kitten]> in
        collection.find().flatMap { cursor in
            cursor.toArray()
        // Hop to ensure that the final response future happens on the request's event loop.
        }.hop(to: req.eventLoop)
    }

    app.get("kittens", ":_id") { req -> EventLoopFuture<Kitten> in
        let idString = req.parameters.get("_id")!
        // If we can't create an ObjectID from the id string, then we know it doesn't correspond
        // to a kitten in the database.
        guard let id = try? BSONObjectID(idString) else {
            throw Abort(.notFound, reason: "No kitten with exists with ID \(idString)")
        }
        return collection.findOne(["_id": .objectID(id)])
            // Hop to ensure that the final response future happens on the request's event loop.
            .hop(to: req.eventLoop)
            .unwrap(or: Abort(.notFound))
    }

    app.post { req -> EventLoopFuture<Response> in
        let newKitten = try req.content.decode(Kitten.self)
        return collection.insertOne(newKitten)
        .hop(to: req.eventLoop)
        .map { _ in
            return req.redirect(to: "/")
        }
        .flatMapErrorThrowing { error in
            // Give a more helpful error message in case of a duplicate key error.
            if let err = error as? MongoSwift.WriteError, err.writeFailure?.code == 11000 {
                throw Abort(.conflict, reason: "A kitten with the name \(newKitten.name) already exists!")
            }
            throw Abort(.internalServerError, reason: "Failed to save new kitten: \(error)")
        }
    }

    app.delete { req -> EventLoopFuture<Response> in
        guard let str = req.body.string, let id = try? BSONObjectID(str) else {
            throw Abort(.badRequest, reason: "Body missing ID")
        }
        return collection.deleteOne(["_id": .objectID(id)])
        .hop(to: req.eventLoop)
        .map { _ in
            return req.redirect(to: "/")
        }
    }
}
