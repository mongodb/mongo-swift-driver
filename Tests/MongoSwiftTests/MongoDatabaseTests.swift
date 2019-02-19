@testable import MongoSwift
import Nimble
import XCTest

final class MongoDatabaseTests: MongoSwiftTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testMongoDatabase() throws {
        let client = try MongoClient(MongoSwiftTestCase.connStr)
        let db = client.db(type(of: self).testDatabase)

        let command: Document = ["create": self.getCollectionName(suffix: "1")]
        expect(try db.runCommand(command)).to(equal(["ok": 1.0]))
        expect(try (Array(db.listCollections()) as [Document]).count).to(equal(1))

        // create collection using createCollection
        expect(try db.createCollection(self.getCollectionName(suffix: "2"))).toNot(throwError())
        expect(try (Array(db.listCollections()) as [Document]).count).to(equal(2))

        let opts = ListCollectionsOptions(filter: ["type": "view"] as Document)
        expect(try db.listCollections(options: opts)).to(beEmpty())

        expect(try db.drop()).toNot(throwError())
        let dbs = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        let names = (Array(dbs) as [Document]).map { $0["name"] as? String ?? "" }
        expect(names).toNot(contain([type(of: self).testDatabase]))

        expect(db.name).to(equal(type(of: self).testDatabase))

        // error code 59: CommandNotFound
        expect(try db.runCommand(["asdfsadf": ObjectId()]))
                .to(throwError(ServerError.commandError(code: 59, message: "", errorLabels: nil)))
    }
}
