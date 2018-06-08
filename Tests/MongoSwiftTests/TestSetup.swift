import Foundation
import MongoSwift

/// This should be assigned to NSPrincipalClass in the project's plist file
class TestSetup: NSObject {
    override init() {
        MongoSwift.initialize()
    }

    deinit {
        MongoSwift.cleanup()
    }
}
