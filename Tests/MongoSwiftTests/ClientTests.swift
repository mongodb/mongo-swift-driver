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
    guard let client = try? Client(connectionString: "mongodb://localhost:27017/") else {
      print("failed to create a client")
      return
    }

    guard let databases = try? client.listDatabases() else {
      print("failed to list databases")
      return
    }

    for database in databases {
      print(database)
    }
  }
}
