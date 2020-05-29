internal func getValue(from document: BSONDocument, for key: String) throws -> BSON? {
    do {
        return try document.getValue(for: key)
    } catch let error as BSONError.InvalidArgumentError {
        throw MongoError.InvalidArgumentError(message: error.message)
    } catch let error as BSONError.InternalError {
        throw MongoError.InternalError(message: error.message)
    }
}

internal func setValue(in document: inout BSONDocument, for key: String, to value: BSON) throws {
    do {
        try document.setValue(for: key, to: value)
    } catch let error as BSONError.InvalidArgumentError {
        throw MongoError.InvalidArgumentError(message: error.message)
    } catch let error as BSONError.InternalError {
        throw MongoError.InternalError(message: error.message)
    }
}

/// If the document already has an _id, returns it as-is. Otherwise, returns a new document
/// containing all the keys from this document, with an _id prepended.
internal func withID(document: BSONDocument) throws -> BSONDocument {
    if document.hasKey("_id") {
        return document
    }

    var idDoc: BSONDocument = ["_id": .objectID()]
    do {
        try idDoc.merge(document)
        return idDoc
    } catch let error as BSONError.InternalError {
        throw MongoError.InternalError(message: error.message)
    }
}
