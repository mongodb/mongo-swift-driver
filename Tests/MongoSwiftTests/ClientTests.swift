import Foundation
@testable import MongoSwift
import XCTest

final class ClientTests: XCTestCase {
  static var allTests: [(String, (ClientTests) -> () throws -> Void)] {
    return [
      ("testClient", testClient)
    ]
  }

  func testClient() {
    let client = try? Client(connectionString: "mongodb://localhost:27017/")
    print("GOT HERE")
  }
}
