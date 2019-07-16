import Foundation

public struct PureBSONDocument {
    private var data: Data

    internal init(elements: [(String, BSON)]) {
        self.data = Data()
    }
}

extension PureBSONDocument: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self.init(elements: elements)
    }
}

extension PureBSONDocument: PureBSONValue {
    internal init(from data: Data) throws {
        // should we do any validation here?
        self.data = data
    }
    
    internal func toBSON() -> Data {
        return self.data
    }
}

extension PureBSONDocument: Equatable {}
extension PureBSONDocument: Hashable {}
