/*
 * BSONUtil contains helpers to wrap the underlying BSON library to assist in providing a consistent API
 */

/// We don't want driver users to handle any BSONErrors
/// this will convert BSONError.* thrown from `fn` to MongoError.* and rethrow
internal func convertingBSONErrors<T>(_ body: () throws -> T) rethrows -> T {
    do {
        return try body()
    } catch let error as BSONError.InvalidArgumentError {
        throw MongoError.InvalidArgumentError(message: error.message)
    } catch let error as BSONError.InternalError {
        throw MongoError.InternalError(message: error.message)
    } catch let error as BSONError.LogicError {
        throw MongoError.LogicError(message: error.message)
    }
}
