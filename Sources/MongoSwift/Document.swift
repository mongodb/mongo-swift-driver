import Foundation
import libbson

public class Document: BsonValue, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    internal var data: UnsafeMutablePointer<bson_t>!

    public var bsonType: BsonType { return .document }

    public init() {
        data = bson_new()
    }

    public init(fromData bsonData: UnsafeMutablePointer<bson_t>) {
        data = bson_copy(bsonData)
    }

    public init(_ doc: [String: BsonValue?]) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }

    public required init(dictionaryLiteral doc: (String, Any?)...) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v as? BsonValue
        }
    }

    public required init(arrayLiteral elements: BsonValue...) {
        data = bson_new()
        for (i, elt) in elements.enumerated() {
            self[String(i)] = elt
        }
    }

    /**
     * Constructs a new `Document` from the provided JSON text
     *
     * - Parameters:
     *   - json: a JSON document to parse into a `Document`
     *
     * - Returns: the parsed `Document`
     */
    public init(fromJson: String) throws {
        var error = bson_error_t()
        let buf = Array(fromJson.utf8)
        guard let bson = bson_new_from_json(buf, buf.count, &error) else {
            throw MongoError.bsonParseError(
                domain: error.domain,
                code: error.code,
                message: toErrorString(error)
            )
        }

        data = bson
    }

    /// Returns a canonical extended JSON representation of this Document
    var extendedJson: String {
        let json = bson_as_canonical_extended_json(self.data, nil)
        guard let jsonData = json else {
            return String()
        }

        return String(cString: jsonData)
    }

    /// Returns a copy of the raw BSON data represented as Data
    var rawBson: Data {
        let data = bson_get_data(self.data)
        let length = self.data.pointee.len
        return Data(bytes: data!, count: Int(length))
    }

    public func encode(to data: UnsafeMutablePointer<bson_t>, forKey key: String) throws {
        if !bson_append_document(data, key, Int32(key.count), self.data) {
            throw bsonEncodeError(value: self, forKey: key)
        }
    }

    public func getData() -> UnsafeMutablePointer<bson_t> {
        return data
    }

    deinit {
        bson_destroy(data)
    }

    public var description: String {
        let json = bson_as_relaxed_extended_json(self.data, nil)
        guard let jsonData = json else {
            return String()
        }

        return String(cString: jsonData)
    }

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
                        let oidPP = UnsafeMutablePointer<UnsafePointer<bson_oid_t>?>.allocate(capacity: 1)
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

extension Document: Equatable {
    public static func == (lhs: Document, rhs: Document) -> Bool {
        return bson_compare(lhs.getData(), rhs.getData()) == 0
    }
}

public func getDataOrNil(_ doc: Document?) -> UnsafeMutablePointer<bson_t>? {
    if let d = doc {
        return d.getData()
    }
    return nil
}
