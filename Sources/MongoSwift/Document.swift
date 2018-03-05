import Foundation
import libbson

/// A class representing the BSON document type
public class Document: BsonValue, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    internal var data: UnsafeMutablePointer<bson_t>!

    public var bsonType: BsonType { return .document }

    /// Initialize a new, empty document
    public init() {
        data = bson_new()
    }

    /**
     * Initializes a `Document` from a pointer to a bson_t. Uses a copy
     * of `bsonData`, so the caller is responsible for freeing the original
     * memory. 
     * 
     * - Parameters:
     *   - bsonData: a UnsafeMutablePointer<bson_t>
     *
     * - Returns: a new `Document`
     */
    internal init(fromData bsonData: UnsafeMutablePointer<bson_t>) {
        data = bson_copy(bsonData)
    }

    /**
     * Initializes a `Document` from a [String: BsonValue?] 
     *
     * - Parameters:
     *   - doc: a [String: BsonValue?]
     *
     * - Returns: a new `Document`
     */
    public init(_ doc: [String: BsonValue?]) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }

    /**
     * Initializes a `Document` using a dictionary literal where the 
     * keys are `String`s and the values are `BsonValue?`s. For example:
     * `d: Document = ["a" : 1 ]`
     *
     * - Parameters:
     *   - dictionaryLiteral: a [String: BsonValue?]
     *
     * - Returns: a new `Document`
     */
    public required init(dictionaryLiteral doc: (String, BsonValue?)...) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }
    /**
     * Initializes a `Document` using an array literal where the values
     * are `BsonValue`s. Values are stored under a string of their 
     * index in the array. For example:
     * `d: Document = ["a", "b"]` will become `["0": "a", "1": "b"]`
     *
     * - Parameters:
     *   - arrayLiteral: a [BsonValue?]
     *
     * - Returns: a new `Document`
     */
    public required init(arrayLiteral elements: BsonValue?...) {
        data = bson_new()
        for (i, elt) in elements.enumerated() {
            self[String(i)] = elt
        }
    }

    /**
     * Constructs a new `Document` from the provided JSON text
     *
     * - Parameters:
     *   - fromJSON: a JSON document as Data to parse into a `Document`
     *
     * - Returns: the parsed `Document`
     */
    public init(fromJSON: Data) throws {
        data = try fromJSON.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            var error = bson_error_t()
            guard let bson = bson_new_from_json(bytes, fromJSON.count, &error) else {
                throw MongoError.bsonParseError(
                    domain: error.domain,
                    code: error.code,
                    message: toErrorString(error)
                )
            }

            return bson
        }
    }

    /// Convenience initializer for constructing a `Document` from a `String`
    public convenience init(fromJSON json: String) throws {
        try self.init(fromJSON: json.data(using: .utf8)!)
    }

    /**
     * Constructs a `Document` from raw BSON data
     */
    public init(fromBSON: Data) {
        data = fromBSON.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            return bson_new_from_data(bytes, fromBSON.count)
        }
    }

    /// Returns a relaxed extended JSON representation of this Document
    var extendedJSON: String {
        let json = bson_as_relaxed_extended_json(self.data, nil)
        guard let jsonData = json else {
            return String()
        }

        return String(cString: jsonData)
    }

    /// Returns a canonical extended JSON representation of this Document
    var canonicalExtendedJSON: String {
        let json = bson_as_canonical_extended_json(self.data, nil)
        guard let jsonData = json else {
            return String()
        }

        return String(cString: jsonData)
    }

    /// Returns a copy of the raw BSON data represented as Data
    var rawBSON: Data {
        let data = bson_get_data(self.data)
        let length = self.data.pointee.len
        return Data(bytes: data!, count: Int(length))
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_document(data, key, Int32(key.count), self.data) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    deinit {
        guard let data = self.data else { return }
        bson_destroy(data)
        self.data = nil
    }

    public var description: String {
        return self.extendedJSON
    }

    /**
     * Allows setting values and retrieving values using subscript syntax.
     * For example:
     * 
     *  let d = Document()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     * 
     */
    subscript(key: String) -> BsonValue? {
        get {
            var iter: bson_iter_t = bson_iter_t()
            if !bson_iter_init(&iter, data) {
                return nil
            }

            func retrieveErrorMsg(_ type: String) -> String {
                return "Failed to retrieve the \(type) value for key '\(key)'"
            }

            while bson_iter_next(&iter) {
                let ikey = String(cString: bson_iter_key(&iter))
                if ikey == key {
                    let itype = bson_iter_type(&iter)
                    switch itype {
                    case BSON_TYPE_ARRAY:
                        return [BsonValue].from(bson: &iter)

                    case BSON_TYPE_BINARY:
                        return Binary.from(bson: &iter)

                    case BSON_TYPE_BOOL:
                        return bson_iter_bool(&iter)

                    case BSON_TYPE_CODE, BSON_TYPE_CODEWSCOPE:
                        return CodeWithScope.from(bson: &iter)

                    case BSON_TYPE_DATE_TIME:
                        return Date(msSinceEpoch: bson_iter_date_time(&iter))

                    // DBPointer is deprecated, so convert to a DBRef doc.
                    case BSON_TYPE_DBPOINTER:
                        var length: UInt32 = 0
                        let collectionPP = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: 1)
                        defer { collectionPP.deallocate(capacity: 1) }
                        let oidPP = UnsafeMutablePointer<UnsafePointer<bson_oid_t>?>.allocate(capacity: 1)
                        defer { oidPP.deallocate(capacity: 1) }
                        bson_iter_dbpointer(&iter, &length, collectionPP, oidPP)

                        guard let oidP = oidPP.pointee else {
                            preconditionFailure(retrieveErrorMsg("DBPointer ObjectId"))
                        }
                        guard let collectionP = collectionPP.pointee else {
                            preconditionFailure(retrieveErrorMsg("DBPointer collection name"))
                        }

                        let dbRef: Document = [
                            "$ref": String(cString: collectionP),
                            "$id": ObjectId(from: oidP.pointee)
                        ]

                        return dbRef

                    case BSON_TYPE_DECIMAL128:
                        return Decimal128.from(bson: &iter)

                    case BSON_TYPE_DOCUMENT:
                        var length: UInt32 = 0
                        let document = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                        defer { document.deallocate(capacity: 1) }

                        bson_iter_document(&iter, &length, document)

                        guard let docData = bson_new_from_data(document.pointee, Int(length)) else {
                            preconditionFailure("Failed to create a bson_t from document data")
                        }

                        return Document(fromData: docData)

                    case BSON_TYPE_DOUBLE:
                        return bson_iter_double(&iter)

                    case BSON_TYPE_INT32:
                        return Int(bson_iter_int32(&iter))

                    case BSON_TYPE_INT64:
                        return bson_iter_int64(&iter)

                    case BSON_TYPE_MINKEY:
                        return MinKey()

                    case BSON_TYPE_MAXKEY:
                        return MaxKey()

                    // Since Undefined is deprecated, convert to null if we encounter it.
                    case BSON_TYPE_NULL, BSON_TYPE_UNDEFINED:
                        return nil

                    case BSON_TYPE_OID:
                        return ObjectId.from(bson: &iter)

                    case BSON_TYPE_REGEX:
                        do { return try NSRegularExpression.from(bson: &iter)
                        } catch {
                            preconditionFailure("Failed to create an NSRegularExpression object " +
                                "from regex data stored for key \(key)")
                        }

                    // Since Symbol is deprecated, return as a string instead.
                    case BSON_TYPE_SYMBOL:
                        var length: UInt32 = 0
                        let value = bson_iter_symbol(&iter, &length)
                        guard let strValue = value else {
                            preconditionFailure(retrieveErrorMsg("Symbol"))
                        }
                        return String(cString: strValue)

                    case BSON_TYPE_TIMESTAMP:
                        return Timestamp.from(bson: &iter)

                    case BSON_TYPE_UTF8:
                        var length: UInt32 = 0
                        let value = bson_iter_utf8(&iter, &length)
                        guard let strValue = value else {
                            preconditionFailure(retrieveErrorMsg("UTF-8"))
                        }

                        return String(cString: strValue)

                    default:
                        return nil
                    }
                }
            }

            return nil
        }

        set(newValue) {

            guard let value = newValue else {
                if !bson_append_null(data, key, Int32(key.count)) {
                    preconditionFailure("Failed to set the value for key \(key) to null")
                }
                return
            }

            do {
                try value.encode(to: data, forKey: key)
            } catch {
                preconditionFailure("Failed to set the value for key \(key) to \(value)")
            }

        }
    }
}

/// An extension of `Document` to make it `Equatable`. 
extension Document: Equatable {
    public static func == (lhs: Document, rhs: Document) -> Bool {
        return bson_compare(lhs.data, rhs.data) == 0
    }
}
