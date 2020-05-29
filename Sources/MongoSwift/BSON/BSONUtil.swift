internal func getValue(from document: BSONDocument, for key: String) throws -> BSON? {
    do {
        return try document.getValue(for: key)
    } catch let error as BSONError.InvalidArgumentError {
        throw BSONError.InvalidArgumentError(message: error.message)
    }
}

internal func setValue(in document: inout BSONDocument, for key: String, to value: BSON) throws {
    do {
        try document.setValue(for: key, to: value)
    } catch let error as BSONError.InvalidArgumentError {
        throw BSONError.InvalidArgumentError(message: error.message)
    }
}
