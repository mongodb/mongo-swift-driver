import Foundation
import libmongoc

/// An extension of `Document` to make it conform to the `Sequence` protocol.
/// This allows you to iterate through the (key, value) pairs, for example:
/// ```
/// let doc: Document = ["a": 1, "b": 2]
/// for (key, value) in doc {
///     ...
/// }
/// ```
extension Document: Sequence {
    /// Returns a `DocumentIterator` over the values in this `Document`. 
    public func makeIterator() -> DocumentIterator {
        guard let iter = DocumentIterator(forDocument: self) else {
            preconditionFailure("Failed to initialize an iterator over document \(self)")
        }
        return iter
    }
}

/// An iterator over the values in a `Document`. 
public class DocumentIterator: IteratorProtocol {
    /// the libbson iterator. it must be a `var` because we use it as
    /// an inout argument
    internal var iter: bson_iter_t

    /// Initializes a new iterator over the contents of `doc`. `doc` must remain alive for 
    /// the lifetime of the iterator. Returns `nil` if the key is not found, or if an iterator 
    /// cannot be created over `doc` due to an error from e.g. corrupt data.
    internal init?(forDocument doc: Document) {
        self.iter = bson_iter_t()
        if !bson_iter_init(&self.iter, doc.data) { return nil }
    }

    /// Initializes a new iterator over the contents of `doc`. `doc` must remain alive for the
    /// lifetime of the iterator. Returns `nil` if an iterator cannot be created over `doc` due
    /// to an error from e.g. corrupt data, or if the key is not found.
    internal init?(forDocument doc: Document, advancedTo key: String) {
        self.iter = bson_iter_t()
        if !bson_iter_init_find(&iter, doc.data, key.cString(using: .utf8)) {
            return nil
        }
    }

    /// Advances the iterator forward one value. Returns false if there is an error moving forward
    /// or if at the end of the document. Returns true otherwise.
    private func advance() -> Bool {
        return bson_iter_next(&self.iter)
    }

    /// Returns the current key. Assumes the iterator is in a valid position.
    internal var currentKey: String {
        return String(cString: bson_iter_key(&self.iter))
    }

    /// Returns the current value. Assumes the iterator is in a valid position.
    internal var currentValue: BsonValue? {
        do {
            switch self.currentType {
            case .symbol:
                return try Symbol.asString(from: self)
            case .dbPointer:
                return try DBPointer.asDocument(from: self)
            default:
                return try DocumentIterator.BsonTypeMap[currentType]?.init(from: self)
            }
        } catch {
            preconditionFailure("Error getting current value from iterator: \(error)")
        }
    }

    /// Returns the current value's type. Assumes the iterator is in a valid position.
    internal var currentType: BsonType {
        return BsonType(rawValue: bson_iter_type(&iter).rawValue) ?? .invalid
    }

    /// Returns the keys from the iterator's current position to the end.
    internal var keys: [String] {
        var keys = [String]()
        while self.advance() { keys.append(self.currentKey) }
        return keys
    }

    /// Returns the values from the iterator's current position to the end.
    internal var values: [BsonValue?] {
        var values = [BsonValue?]()
        while self.advance() { values.append(self.currentValue) }
        return values
    }

    /// Returns the next value in the sequence, or `nil` if at the end.
    public func next() -> (key: String, value: BsonValue?)? {
        if self.advance() {
            return (self.currentKey, self.currentValue)
        }
        return nil
    }

    private static let BsonTypeMap: [BsonType: BsonValue.Type] = [
        .double: Double.self,
        .string: String.self,
        .document: Document.self,
        .array: [BsonValue?].self,
        .binary: Binary.self,
        .objectId: ObjectId.self,
        .boolean: Bool.self,
        .dateTime: Date.self,
        .regularExpression: RegularExpression.self,
        .dbPointer: DBPointer.self,
        .javascript: CodeWithScope.self,
        .symbol: Symbol.self,
        .javascriptWithScope: CodeWithScope.self,
        .int32: Int.self,
        .timestamp: Timestamp.self,
        .int64: Int64.self,
        .decimal128: Decimal128.self,
        .minKey: MinKey.self,
        .maxKey: MaxKey.self
    ]
}
