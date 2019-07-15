import Foundation

public enum BSON {
    case double(Double)
    case string(String)
}

internal protocol PureBSONValue {
    init(from data: Data) throws
    func toBSON() -> Data
}