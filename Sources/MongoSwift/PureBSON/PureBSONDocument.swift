import Foundation

public struct PureBSONDocument {
    private var data: Data
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
