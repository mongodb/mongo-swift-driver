import MongoSwiftSync
import Nimble
import TestsCommon
import XCTest

final class ReadPreferenceOperationTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testOperationReadPreference() throws {
        // setup a collection
        let client = try MongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName(suffix: "1"))

        let command: Document = ["count": .string(coll.name)]

        // expect runCommand to return a success response when passing in a valid read preference
        let opts = RunCommandOptions(readPreference: ReadPreference(.secondaryPreferred))
        let res = try db.runCommand(command, options: opts)
        expect(res["ok"]?.asDouble()).to(equal(1.0))

        // expect running other commands to not throw errors when passing in a valid read preference
        expect(try coll.find(options: FindOptions(readPreference: ReadPreference(.primary)))).toNot(throwError())
        expect(try coll.findOne(options: FindOneOptions(readPreference: ReadPreference(.primary)))).toNot(throwError())

        expect(try coll.aggregate(
            [["$project": ["a": 1]]],
            options: AggregateOptions(readPreference: ReadPreference(.secondaryPreferred))
        )).toNot(throwError())

        expect(try coll.countDocuments(
            options:
            CountDocumentsOptions(readPreference: ReadPreference(.secondaryPreferred))
        )).toNot(throwError())

        expect(try coll.distinct(
            fieldName: "a",
            options: DistinctOptions(readPreference: ReadPreference(.secondaryPreferred))
        )).toNot(throwError())
    }
}
