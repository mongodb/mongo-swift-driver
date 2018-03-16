/// Unwraps the optional value `obj`, and throws `error` if `obj` is nil.
internal func unwrap<T>(_ obj: T?, elseThrow error: MongoError) throws -> T {
    guard let o = obj else { throw error }
    return o
}
