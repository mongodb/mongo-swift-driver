@testable import MongoSwift
import Quick
import Nimble
import XCTest

class DatabaseTests: QuickSpec {

    override func setUp() {
         continueAfterFailure = false
    }

    override func spec() {

        it("Should correctly perform simple database operations") {

            guard let client = try? MongoClient() else {
                XCTFail("failed to create a client")
                return
            }

            guard let db = try? client.db("testDB") else {
                 XCTFail("failed to list databases")
                 return
            }

            // create collection using runCommand
            let command: Document = ["create": "coll1"]
            expect { try db.runCommand(command) }.to(equal(["ok": 1.0]))
            expect { try db.collection("coll1") }.toNot(throwError())

            // create collection using createCollection
            expect { try db.createCollection("coll2") }.toNot(throwError())
            expect { try (Array(db.listCollections()) as [Document]).count }.to(equal(2))

            let opts = ListCollectionsOptions(filter: ["type": "view"] as Document, batchSize: nil, session: nil)
            expect { try db.listCollections(options: opts) }.to(beEmpty())

            expect { try db.drop() }.toNot(throwError())
            let dbs = try? client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
            expect(dbs).toNot(beNil())
            let names = (Array(dbs!) as [Document]).map { $0["name"] as? String ?? "" }
            expect(names).toNot(contain(["testDB"]))
        }
    }
}
