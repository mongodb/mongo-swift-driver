import mongoc

/// A token used for manually resuming a change stream. Pass this to the `resumeAfter` or `startAfter` fields of
/// `ChangeStreamOptions` to resume or start a change stream where a previous one left off.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/#resume-a-change-stream
public struct ChangeStreamToken: Codable {
    private let resumeToken: Document

    public init(resumeToken: Document) {
        self.resumeToken = resumeToken
    }

    public init(from decoder: Decoder) throws {
      self.resumeToken = try Document(from: decoder)
    }
}

/// A MongoDB ChangeStream.
/// - SeeAlso: https://docs.mongodb.com/manual/changeStreams/
public class ChangeStream<T: Codable>: Sequence, IteratorProtocol {
  /// A `ChangeStreamToken` used to manually resume a change stream.
  public private(set) var resumeToken: ChangeStreamToken

  /// A `MongoClient` stored to make sure the source client stays valid
  /// until the change stream is destroyed.
  private var client: MongoClient?

  /// A `ClientSession` stored to make sure the session stays valid
  /// until the change stream is destroyed.
  private var session: ClientSession?

  /// A reference to the `mongoc_change_stream_t` pointer.
  private var changeStream: OpaquePointer?

  /// Used for storing Swift errors.
  private var swiftError: Error?

  /// The error that occurred while iterating the ChangeStream cursor, if one exists.
  /// This should be used to check for errors after `next()` returns `nil`.
  public var error: Error? {
    if let err = self.swiftError {
        return err
    }

    var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
    defer {
        replyPtr.deinitialize(count: 1)
        replyPtr.deallocate()
    }

    var error = bson_error_t()
    guard mongoc_cursor_error_document(self.changeStream, &error, replyPtr) else {
        return nil
    }

    // If a reply is present, it implies the error occurred on the server. This *should* always be a commandError,
    // but we will still parse the mongoc error to cover all cases.
    if let docPtr = replyPtr.pointee {
        // we have to copy because libmongoc owns the pointer.
        let reply = Document(copying: docPtr)
        return extractMongoError(error: error, reply: reply)
    }

    // Otherwise, the only feasible error is that the user tried to advance a dead change stream cursor,
    // which is a logic error. We will still parse the mongoc error to cover all cases.
    return extractMongoError(error: error)
  }

  /// Decoder for decoding documents into type `T`.
  internal let decoder: BSONDecoder

  /// Returns the next `T` in the change stream or nil if there is no next value. Will block for a maximum of
  /// `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout
  /// if omitted.
  public func next() -> T? {
    let cursor = self.changeStream
    // Allocate space for a reference to a BSON pointer.
    let out = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
    defer {
        out.deinitialize(count: 1)
        out.deallocate()
    }

    // Check that there’s another document in the stream.
    guard mongoc_change_stream_next(cursor, out) else {
      return nil
    }

    guard let pointee = out.pointee else {
        fatalError("Could not advance the change stream.")
    }

    // we have to copy because libmongoc owns the pointer.
    let doc = Document(copying: pointee)

    // Update the resumeToken with the `_id` field from the document.
    if let resumeToken = doc["_id"] as? Document {
        self.resumeToken = ChangeStreamToken(resumeToken: resumeToken)
    } else {
        self.swiftError = RuntimeError.internalError(message: "_id field is missing from the change stream document.")
        return nil
    }

    do {
        return try decoder.decode(T.self, from: doc)
    } catch {
        self.swiftError = error
    }

    return nil
  }

  /**
   * Returns the next `T` in this change stream or `nil`, or throws an error if one occurs -- compared to `next()`,
   * whichreturns `nil` and requires manually checking for an error afterward. Will block for a maximum of
   * `maxAwaitTimeMS` milliseconds as specified in the `ChangeStreamOptions`, or for the server default timeout if
   * omitted.
   * - Returns: the next `T` in this change stream, or `nil` if at the end of the change stream cursor.
   * - Throws:
   *   - `ServerError.commandError` if an error occurs on the server while iterating the change stream cursor.
   *   - `UserError.logicError` if this function is called and the session associated with this change stream is
   *     inactive.
   *   - `DecodingError` if an error occurs decoding the server's response.
   */
  public func nextOrError() throws -> T? {
    if let next = self.next() {
      return next
    }

    if let error = self.error {
      throw error
    }
    return nil
  }

  /**
   * Initializes a `ChangeStream`.
   * - Throws:
   *   - `ServerError.commandError` if an error occurred on the server when creating the `mongoc_change_stream_t`.
   *   - `UserError.invalidArgumentError` if the `mongoc_change_stream_t` was created with invalid options.
   */
  internal init(stealing changeStream: OpaquePointer,
                client: MongoClient,
                session: ClientSession? = nil,
                decoder: BSONDecoder) throws {
    self.changeStream = changeStream
    self.session = session
    self.client = client
    self.decoder = decoder
    self.resumeToken = ChangeStreamToken(resumeToken: [])

    if let err = self.error {
      throw err
    }
  }

  /// Cleans up internal state.
  deinit {
    guard let cursor = self.changeStream else {
        return
    }
    mongoc_cursor_destroy(changeStream)
    self.changeStream = nil
    self.session = nil
    self.client = nil
  }
}
