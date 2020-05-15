import CLibMongoC

/// Executes the provided closure using a stack-allocated, mutable bson_t. The bson_t is only valid for the body of the
/// closure and must be copied if you wish to use it later on.
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
    command: Document,
    options: Document?,
    body: MongocCommandFunc
) throws -> Document {
    try withStackAllocatedMutableBSONPointer { replyPtr in
        try _runMongocCommand(command: command, options: options, replyPtr: replyPtr, body: body)
        return Document(copying: replyPtr)
    }
}

/// Calls the provided mongoc command method using pointers to the specified command and options.
internal func runMongocCommand(command: Document, options: Document?, body: MongocCommandFunc) throws {
    try withStackAllocatedMutableBSONPointer { replyPtr in
        try _runMongocCommand(command: command, options: options, replyPtr: replyPtr, body: body)
    }
}

/// Private helper to run the provided `MongocCommandFunc` using the specified location for a reply.
private func _runMongocCommand(
    command: Document,
    options: Document?,
    replyPtr: MutableBSONPointer,
    body: MongocCommandFunc
) throws {
    var error = bson_error_t()
    return try command.withBSONPointer { cmdPtr in
        try withOptionalBSONPointer(to: options) { optsPtr in
            let success = body(cmdPtr, optsPtr, replyPtr, &error)
            guard success else {
                throw extractMongoError(error: error, reply: Document(copying: replyPtr))
            }
        }
    }
}
