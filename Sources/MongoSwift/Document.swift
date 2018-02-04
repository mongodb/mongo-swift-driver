import Foundation
import libbson

public class Document: ExpressibleByDictionaryLiteral {
    internal var data: UnsafeMutablePointer<bson_t>!

    public init() {
        data = bson_new()
    }

    public init(fromData bsonData: UnsafeMutablePointer<bson_t>) {
        data = bsonData
    }

    public init(_ doc: [String: BsonValue]) {
        data = bson_new()
        for (key, value) in doc {
            self[key] = value
        }
    }

   public required init(dictionaryLiteral doc: (String, BsonValue)...) {
        data = bson_new()
        for (k, v) in doc {
            self[k] = v
        }
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

                        let arrayLen = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
                        let array = UnsafeMutablePointer<UnsafePointer<UInt8>?>.allocate(capacity: 1)
                        bson_iter_array(&iter, arrayLen, array)

                        // since an array is a nested object with keys '0', '1', etc., 
                        // create a new Document using the array data so we can recursively parse
                        guard let b = bson_new_from_data(array.pointee, Int(arrayLen.pointee)) else {
                            preconditionFailure("Failed to create a BSON object from array data stored for key \(key)")
                        }

                        let arrayDoc = Document(fromData: b)

                        var i = 0
                        var result = [BsonValue]()
                        while let v = arrayDoc[String(i)] {
                            result.append(v)
                            i += 1
                        }
                        return result

                    case BSON_TYPE_BOOL:
                        return bson_iter_bool(&iter)

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
            guard let value = newValue else { return }
            let keySize = Int32(key.count)
            var res = false

            switch (value.bsonType, value) {

            case (.array, let val as [BsonValue]):
                // An array is just a document with keys '0', '1', etc.
                // corresponding to indexes
                let arr = Document()
                for (i, v) in val.enumerated() { arr[String(i)] = v }
                res = bson_append_array(data, key, keySize, arr.data)

            case (.boolean, let val as Bool):
                res = bson_append_bool(data, key, keySize, val)

            case (.double, let val as Double):
                res = bson_append_double(data, key, keySize, val)

            case (.int32, _):
                if let val = value as? Int {
                    res = bson_append_int32(data, key, keySize, Int32(val))
                } else if let val = value as? Int32 {
                    res = bson_append_int32(data, key, keySize, val)
                }

            case (.int64, let val as Int64):
                res = bson_append_int64(data, key, keySize, val)

            case (.minKey, _ as MinKey):
                res = bson_append_minkey(data, key, keySize)

            case (.maxKey, _ as MaxKey):
                res = bson_append_maxkey(data, key, keySize)

            case (.string, let val as String):
                res = bson_append_utf8(data, key, keySize, val, Int32(val.count))

            default:
                print("default")
                return
            }

            precondition(res, "Failed to set the value for key '\(key)' to" +
                " \(String(describing: newValue)) with BSON type \(value.bsonType)")

        }
    }
}
