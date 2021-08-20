import CLibMongoC

/// Executes the provided closure using a stack-allocated, uninitialized, mutable bson_t. The bson_t is only valid for
/// the body of the closure and must be copied if you wish to use it later on. The closure *must* initialize the
/// bson_t, or else the deferred call to `bson_destroy` will access uninitialized memory.
internal func withStackAllocatedMutableBSONPointer<T>(body: (MutableBSONPointer) throws -> T) rethrows -> T {
    var bson = bson_t()
    defer {
        withUnsafeMutablePointer(to: &bson) { ptr in
            bson_destroy(ptr)
        }
    }
    return try withUnsafeMutablePointer(to: &bson) { ptr in
        try body(ptr)
    }
}

/// Signature for a Swift closure that wraps a mongoc run_command variant.
internal typealias MongocCommandFunc =
    (_ command: BSONPointer, _ opts: BSONPointer?, _ reply: MutableBSONPointer, _ error: inout bson_error_t) -> (Bool)

/// Calls the provided mongoc command method using pointers to the specified command and options. Returns the resulting
/// reply document from the server. If you do not need to use the reply document, `runMongocCommand` is preferable as
/// it does not perform a copy of the reply.
internal func runMongocCommandWithReply(
    command: BSONDocument,
    options: BSONDocument?,
    body: MongocCommandFunc
) throws -> BSONDocument {
    try withStackAllocatedMutableBSONPointer { replyPtr in
        try _runMongocCommand(command: command, options: options, replyPtr: replyPtr, body: body)
        return BSONDocument(copying: replyPtr)
    }
}

/**
 * Calls the provided mongoc command method using pointers to the specified command and options. Returns the resulting
 * filled-out `bson_t` from libmongoc.
 * The caller of this method is responsible for ensuring the reply `bson_t` is properly cleaned up.
 * If you need a `BSONDocument` reply, use `runMongocCommandWithReply` instead.
 * If you don't need the reply, use `runMongocCommand` instead.
 */
internal func runMongocCommandWithCReply(
    command: BSONDocument,
    options: BSONDocument?,
    body: MongocCommandFunc
) throws -> bson_t {
    var reply = bson_t()
    do {
        try withUnsafeMutablePointer(to: &reply) { replyPtr in
            try _runMongocCommand(command: command, options: options, replyPtr: replyPtr, body: body)
        }
    } catch {
        withUnsafeMutablePointer(to: &reply) { ptr in
            bson_destroy(ptr)
        }
        throw error
    }
    return reply
}

/// Calls the provided mongoc command method using pointers to the specified command and options.
internal func runMongocCommand(command: BSONDocument, options: BSONDocument?, body: MongocCommandFunc) throws {
    try withStackAllocatedMutableBSONPointer { replyPtr in
        try _runMongocCommand(command: command, options: options, replyPtr: replyPtr, body: body)
    }
}

/// Private helper to run the provided `MongocCommandFunc` using the specified location for a reply.
private func _runMongocCommand(
    command: BSONDocument,
    options: BSONDocument?,
    replyPtr: MutableBSONPointer,
    body: MongocCommandFunc
) throws {
    var error = bson_error_t()
    return try command.withBSONPointer { cmdPtr in
        try withOptionalBSONPointer(to: options) { optsPtr in
            let success = body(cmdPtr, optsPtr, replyPtr, &error)
            guard success else {
                throw extractMongoError(error: error, reply: BSONDocument(copying: replyPtr))
            }
        }
    }
}
