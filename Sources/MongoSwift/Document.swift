import Foundation
import libbson

public class Document: BsonValue, ExpressibleByDictionaryLiteral {
    internal var data: UnsafeMutablePointer<bson_t>!

    public var bsonType: BsonType { return .document }

    public init() {
        data = bson_new()
    }

    public init(fromData bsonData: UnsafeMutablePointer<bson_t>) {
        data = bsonData
    }

    public init(_ doc: [String: BsonValue]) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }

   public required init(dictionaryLiteral doc: (String, BsonValue?)...) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
    }

    public func bsonAppend(data: UnsafeMutablePointer<bson_t>, key: String) -> Bool {
        return bson_append_document(data, key, Int32(key.count), self.data)
    }

    deinit {
        bson_destroy(data)
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
                        return [BsonValue].fromBSON(&iter)

                    case BSON_TYPE_BOOL:
                        return bson_iter_bool(&iter)

                    case BSON_TYPE_CODE, BSON_TYPE_CODEWSCOPE:
                        return JavascriptCode.fromBSON(&iter)

                    case BSON_TYPE_DATE_TIME:
                        return Date(msSinceEpoch: bson_iter_date_time(&iter))

                    case BSON_TYPE_DOCUMENT:
                        let docLen = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
                        let document = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                        bson_iter_document(&iter, docLen, document)

                        let docData = UnsafeMutablePointer<bson_t>.allocate(capacity: 1)
                        precondition(bson_init_static(docData, document.pointee, Int(docLen.pointee)),
                            "Failed to create a bson_t from document data")

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

                    case BSON_TYPE_NULL:
                        return nil

                    case BSON_TYPE_OID:
                        return ObjectId.fromBSON(&iter)

                    case BSON_TYPE_REGEX:
                        do { return try NSRegularExpression.fromBSON(&iter)
                        } catch {
                            preconditionFailure("Failed to create an NSRegularExpression object " +
                                "from regex data stored for key \(key)")
                        }

                    case BSON_TYPE_TIMESTAMP:
                        return Timestamp.fromBSON(&iter)

                    case BSON_TYPE_UTF8:
                        let len = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
                        let value = bson_iter_utf8(&iter, len)
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
                let res = bson_append_null(data, key, Int32(key.count))
                precondition(res, "Failed to set the value for key \(key) to null")
                return
            }

            let res = value.bsonAppend(data: data, key: key)
            precondition(res, "Failed to set the value for key '\(key)' to" +
                " \(String(describing: newValue)) with BSON type \(value.bsonType)")

        }
    }
}
