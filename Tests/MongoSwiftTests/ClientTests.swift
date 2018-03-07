@testable import MongoSwift
import Quick
import Nimble

class ClientTests: QuickSpec {

    override func setUp() {
         continueAfterFailure = false
    }

    override func spec() {

        it("Should successfully connect to a client") {
            expect { try MongoClient() }.toNot(throwError())
        }

        it("Should correctly list databases") {
            let client = try? MongoClient()
            expect(client).toNot(beNil())
            let databases = try? client!.listDatabases(options: ListDatabasesOptions(nameOnly: true))
            expect(databases).toNot(beNil())
            let expectedDbs: [Document] = [["name": "admin"], ["name": "config"], ["name": "local"]]
            expect(Array(databases!) as [Document]).to(equal(expectedDbs))
        }
    }
}
