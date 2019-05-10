import Foundation
import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class MongoClientTests: MongoSwiftTestCase {
    func testListDatabases() throws {
        let client = try MongoClient()
        let databases = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        expect((Array(databases) as [Document]).count).to(beGreaterThan(0))
    }

    func testOpaqueInitialization() throws {
        let connectionString = MongoSwiftTestCase.connStr
        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw parseMongocError(error)
        }

        guard let client_t = mongoc_client_new_from_uri(uri) else {
            throw UserError.invalidArgumentError(message: "libmongoc not built with TLS support.")
        }

        let client = MongoClient(stealing: client_t)
        let db = client.db(type(of: self).testDatabase)
        let coll = db.collection(self.getCollectionName())
        let insertResult = try coll.insertOne([ "test": 42 ])
        let findResult = try coll.find([ "_id": insertResult!.insertedId ])
        let docs = Array(findResult)
        expect(docs[0]["test"]).to(bsonEqual(42))
        try db.drop()
    }

    func testFailedClientInitialization() {
        // check that we fail gracefully with an error if passing in an invalid URI
        expect(try MongoClient("abcd")).to(throwError(UserError.invalidArgumentError(message: "")))
    }

    func testServerVersion() throws {
        typealias Version = ServerVersion

        expect(try MongoClient().serverVersion()).toNot(throwError())

        let three6 = Version(major: 3, minor: 6)
        let three61 = Version(major: 3, minor: 6, patch: 1)
        let three7 = Version(major: 3, minor: 7)

        // test equality
        expect(try Version("3.6")).to(equal(three6))
        expect(try Version("3.6.0")).to(equal(three6))
        expect(try Version("3.6.0-rc1")).to(equal(three6))

        expect(try Version("3.6.1")).to(equal(three61))
        expect(try Version("3.6.1.1")).to(equal(three61))

        // lt
        expect(three6 < three6).to(beFalse())
        expect(three6 < three61).to(beTrue())
        expect(three61 < three6).to(beFalse())
        expect(three61 < three7).to(beTrue())
        expect(three7 < three6).to(beFalse())
        expect(three7 < three61).to(beFalse())

        // lte
        expect(three6 <= three6).to(beTrue())
        expect(three6 <= three61).to(beTrue())
        expect(three61 <= three6).to(beFalse())
        expect(three61 <= three7).to(beTrue())
        expect(three7 <= three6).to(beFalse())
        expect(three7 <= three61).to(beFalse())

        // gt
        expect(three6 > three6).to(beFalse())
        expect(three6 > three61).to(beFalse())
        expect(three61 > three6).to(beTrue())
        expect(three61 > three7).to(beFalse())
        expect(three7 > three6).to(beTrue())
        expect(three7 > three61).to(beTrue())

        // gte
        expect(three6 >= three6).to(beTrue())
        expect(three6 >= three61).to(beFalse())
        expect(three61 >= three6).to(beTrue())
        expect(three61 >= three7).to(beFalse())
        expect(three7 >= three6).to(beTrue())
        expect(three7 >= three61).to(beTrue())

        // invalid strings
        expect(try Version("hi")).to(throwError())
        expect(try Version("3")).to(throwError())
        expect(try Version("3.x")).to(throwError())
    }

    struct Wrapper: Codable, Equatable {
        let _id: String
        let date: Date
        let uuid: UUID
        let data: Data

        static func == (lhs: Wrapper, rhs: Wrapper) -> Bool {
            return lhs.date == rhs.date && lhs.data == rhs.data && lhs.uuid == rhs.uuid
        }
    }

    func testCodingStrategies() throws {
        let date = Date(timeIntervalSince1970: 100)
        let uuid = UUID()
        let data = Data(base64Encoded: "dGhlIHF1aWNrIGJyb3duIGZveCBqdW1wZWQgb3ZlciB0aGUgbGF6eSBzaGVlcCBkb2cu")!

        let wrapperWithId = { id in Wrapper(_id: id, date: date, uuid: uuid, data: data) }
        let wrapper = wrapperWithId("baseline")

        let defaultClient = try MongoClient()
        let defaultDb = defaultClient.db(type(of: self).testDatabase)
        let collDoc = defaultDb.collection(self.getCollectionName())

        // default behavior is .bsonDate, .binary, .binary
        let collDefault = defaultDb.collection(self.getCollectionName(), withType: Wrapper.self)

        let defaultId = "default"
        try collDefault.insertOne(wrapperWithId(defaultId))

        var doc = try collDoc.find(["_id": defaultId]).nextOrError()
        expect(doc).toNot(beNil())
        expect(doc?["date"] as? Date).to(equal(date))
        expect(doc?["uuid"] as? Binary).to(equal(try Binary(from: uuid)))
        expect(doc?["data"] as? Binary).to(equal(try Binary(data: data, subtype: .generic)))

        expect(try collDefault.find(["_id": defaultId]).nextOrError()).to(equal(wrapper))

        // Customize strategies on the client
        let custom = ClientOptions(
                dateCodingStrategy: .secondsSince1970,
                uuidCodingStrategy: .deferredToUUID,
                dataCodingStrategy: .base64
        )
        let clientCustom = try MongoClient(options: custom)
        let collClient = clientCustom.db(defaultDb.name).collection(collDoc.name, withType: Wrapper.self)

        let collClientId = "customClient"
        try collClient.insertOne(wrapperWithId(collClientId))

        doc = try collDoc.find(["_id": collClientId] as Document).nextOrError()
        expect(doc).toNot(beNil())
        expect(doc?["date"] as? Double).to(beCloseTo(date.timeIntervalSince1970, within: 0.001))
        expect(doc?["uuid"] as? String).to(equal(uuid.uuidString))
        expect(doc?["data"] as? String).to(equal(data.base64EncodedString()))

        expect(try collClient.find(["_id": collClientId]).nextOrError()).to(equal(wrapper))

        // Construct db with differing strategies from client
        let dbOpts = DatabaseOptions(
                dateCodingStrategy: .deferredToDate,
                uuidCodingStrategy: .binary,
                dataCodingStrategy: .binary
        )
        let dbCustom = clientCustom.db(defaultDb.name, options: dbOpts)
        let collDb = dbCustom.collection(collClient.name, withType: Wrapper.self)

        let customDbId = "customDb"
        try collDb.insertOne(wrapperWithId(customDbId))

        doc = try collDoc.find(["_id": customDbId] as Document).next()
        expect(doc).toNot(beNil())
        expect(doc?["date"] as? Double).to(beCloseTo(date.timeIntervalSinceReferenceDate, within: 0.001))
        expect(doc?["uuid"] as? Binary).to(equal(try Binary(from: uuid)))
        expect(doc?["data"] as? Binary).to(equal(try Binary(data: data, subtype: .generic)))

        expect(try collDb.find(["_id": customDbId] as Document).nextOrError()).to(equal(wrapper))

        // Construct collection with differing strategies from database
        let dbCollOpts = CollectionOptions(
                dateCodingStrategy: .millisecondsSince1970,
                uuidCodingStrategy: .deferredToUUID,
                dataCodingStrategy: .base64
        )
        let collCustom = dbCustom.collection(collClient.name, withType: Wrapper.self, options: dbCollOpts)

        let customDbCollId = "customDbColl"
        try collCustom.insertOne(wrapperWithId(customDbCollId))
        doc = try collDoc.find(["_id": customDbCollId]).nextOrError()

        expect(doc).toNot(beNil())
        expect(doc?["date"]).to(bsonEqual(date.msSinceEpoch))
        expect(doc?["uuid"] as? String).to(equal(uuid.uuidString))
        expect(doc?["data"] as? String).to(equal(data.base64EncodedString()))

        expect(try collCustom.find(["_id": customDbCollId] as Document).nextOrError())
                .to(equal(wrapper))

        try defaultDb.drop()
    }
}
