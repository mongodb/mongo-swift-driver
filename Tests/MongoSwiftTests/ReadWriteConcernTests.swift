import mongoc
@testable import MongoSwift
import Nimble
import XCTest

extension WriteConcern {
    /// Initialize a new `WriteConcern` from a `Document`. We can't
    /// use `decode` because the format is different in spec tests
    /// ("journal" instead of "j", etc.)
    fileprivate init(_ doc: Document) throws {
        let j = doc["journal"] as? Bool

        var w: W?
        if let wtag = doc["w"] as? String {
            w = wtag == "majority" ? .majority : .tag(wtag)
        } else if let wInt = (doc["w"] as? BSONNumber)?.int32Value {
            w = .number(wInt)
        }

        let wt = (doc["wtimeoutMS"] as? BSONNumber)?.int64Value

        try self.init(journal: j, w: w, wtimeoutMS: wt)
    }
}

/// Indicates that a type has a read concern property, as well as a way to get a read concern from an instance of the
/// corresponding mongoc type.
protocol ReadConcernable {
    var readConcern: ReadConcern? { get }
    func getMongocReadConcern() throws -> ReadConcern?
}

/// Indicates that a type has a write concern property, as well as a way to get a write concern from an instance of the
/// corresponding mongoc type.
protocol WriteConcernable {
    var writeConcern: WriteConcern? { get }
     func getMongocWriteConcern() throws -> WriteConcern?
}

extension SyncMongoClient: ReadConcernable, WriteConcernable {
    func getMongocReadConcern() throws -> ReadConcern? {
        return try self.connectionPool.withConnection { conn in
            ReadConcern(from: mongoc_client_get_read_concern(conn.clientHandle))
        }
    }
    func getMongocWriteConcern() throws -> WriteConcern? {
        return try self.connectionPool.withConnection { conn in
            WriteConcern(from: mongoc_client_get_write_concern(conn.clientHandle))
        }
    }
}

extension SyncMongoDatabase: ReadConcernable, WriteConcernable {
   func getMongocReadConcern() throws -> ReadConcern? {
        return try self._client.connectionPool.withConnection { conn in
            self.withMongocDatabase(from: conn) { dbPtr in
                ReadConcern(from: mongoc_database_get_read_concern(dbPtr))
            }
        }
    }
    func getMongocWriteConcern() throws -> WriteConcern? {
        return try self._client.connectionPool.withConnection { conn in
            self.withMongocDatabase(from: conn) { dbPtr in
                WriteConcern(from: mongoc_database_get_write_concern(dbPtr))
            }
        }
    }
}

extension SyncMongoCollection: ReadConcernable, WriteConcernable {
    func getMongocReadConcern() throws -> ReadConcern? {
        return try self._client.connectionPool.withConnection { conn in
            self.withMongocCollection(from: conn) { collPtr in
                ReadConcern(from: mongoc_collection_get_read_concern(collPtr))
            }
        }
    }
     func getMongocWriteConcern() throws -> WriteConcern? {
        return try self._client.connectionPool.withConnection { conn in
            self.withMongocCollection(from: conn) { collPtr in
                WriteConcern(from: mongoc_collection_get_write_concern(collPtr))
            }
        }
    }
}

final class ReadWriteConcernTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testReadConcernType() throws {
        // check level var works as expected
        let rc = ReadConcern(.majority)
        expect(rc.level).to(equal(.majority))

        // test empty init
        let rc2 = ReadConcern()
        expect(rc2.level).to(beNil())
        expect(rc2.isDefault).to(beTrue())

        // test init from doc
        let rc3 = ReadConcern(["level": "majority"])
        expect(rc3.level).to(equal(.majority))

        // test string init
        let rc4 = ReadConcern("majority")
        expect(rc4.level).to(equal(.majority))

        // test init with unknown level
        let rc5 = ReadConcern("blah")
        expect(rc5.level).to(equal(.other(level: "blah")))
    }

    func testWriteConcernType() throws {
        // try creating write concerns with various valid options
        expect(try WriteConcern(w: .number(0))).toNot(throwError())
        expect(try WriteConcern(w: .number(3))).toNot(throwError())
        expect(try WriteConcern(journal: true, w: .number(1))).toNot(throwError())
        expect(try WriteConcern(w: .number(0), wtimeoutMS: 1000)).toNot(throwError())
        expect(try WriteConcern(w: .tag("hi"))).toNot(throwError())
        expect(try WriteConcern(w: .majority)).toNot(throwError())

        // verify that this combination is considered invalid
        expect(try WriteConcern(journal: true, w: .number(0)))
                .to(throwError(UserError.invalidArgumentError(message: "")))

        // verify that a negative value for w or for wtimeoutMS is considered invalid
        expect(try WriteConcern(w: .number(-1)))
                .to(throwError(UserError.invalidArgumentError(message: "")))
        expect(try WriteConcern(wtimeoutMS: -1))
                .to(throwError(UserError.invalidArgumentError(message: "")))
    }

    /// Checks that a type T, as well as pointers to corresponding libmongoc instances, has the expected read concern.
    func checkReadConcern<T: ReadConcernable>(_ instance: T,
                                              _ expected: ReadConcern,
                                              _ description: String) throws {
        if expected.isDefault {
            expect(instance.readConcern).to(beNil(), description: description)
        } else {
            expect(instance.readConcern).to(equal(expected), description: description)
        }

        expect(try instance.getMongocReadConcern()).to(equal(expected))
    }

    /// Checks that a type T, as well as pointers to corresponding libmongoc instances, has the expected write concern.
    func checkWriteConcern<T: WriteConcernable>(_ instance: T,
                                                _ expected: WriteConcern,
                                                _ description: String) throws {
        if expected.isDefault {
            expect(instance.writeConcern).to(beNil(), description: description)
        } else {
            expect(instance.writeConcern).to(equal(expected), description: description)
        }

        expect(try instance.getMongocWriteConcern()).to(equal(expected))
    }

    func testClientReadConcern() throws {
        let empty = ReadConcern()
        let majority = ReadConcern(.majority)
        let majorityString = ReadConcern("majority")
        let local = ReadConcern(.local)

        // test behavior of a client with initialized with no RC
        do {
            let client = try SyncMongoClient()
            let clientDesc = "client created with no RC provided"
            // expect the client to have empty/server default read concern
            try checkReadConcern(client, empty, clientDesc)

            // expect that a DB created from this client inherits its unset RC
            let db1 = client.db(type(of: self).testDatabase)
            try checkReadConcern(db1, empty, "db created with no RC provided from \(clientDesc)")

            // expect that a DB created from this client can override the client's unset RC
            let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: majority))
            try checkReadConcern(db2, majority, "db created with majority RC from \(clientDesc)")
        }

        // test behavior of a client initialized with local RC
        do {
            let client = try SyncMongoClient(options: ClientOptions(readConcern: local))
            let clientDesc = "client created with local RC"
            // although local is default, if it is explicitly provided it should be set
            try checkReadConcern(client, local, clientDesc)

            // expect that a DB created from this client inherits its local RC
            let db1 = client.db(type(of: self).testDatabase)
            try checkReadConcern(db1, local, "db created with no RC provided from \(clientDesc)")

            // expect that a DB created from this client can override the client's local RC
            let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: majority))
            try checkReadConcern(db2, majority, "db created with majority RC from \(clientDesc)")

            // test with string init
            let db3 = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: majorityString))
            try checkReadConcern(db3, majority, "db created with majority string RC from \(clientDesc)")

            // test with unknown level
            let unknown = ReadConcern("blah")
            let db4 = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: unknown))
            try checkReadConcern(db4, unknown, "db created with unknown RC from \(clientDesc)")
        }

        // test behavior of a client initialized with majority RC
        do {
            var client = try SyncMongoClient(options: ClientOptions(readConcern: majority))
            let clientDesc = "client created with majority RC"
            try checkReadConcern(client, majority, clientDesc)

            // test with string init
            client = try SyncMongoClient(options: ClientOptions(readConcern: majorityString))
            try checkReadConcern(client, majority, "\(clientDesc) string")

            // expect that a DB created from this client can override the client's majority RC with an unset one
            let db = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: empty))
            try checkReadConcern(db, empty, "db created with empty RC from \(clientDesc) string")
        }
    }

    func testClientWriteConcern() throws {
        let w1 = try WriteConcern(w: .number(1))
        let w2 = try WriteConcern(w: .number(2))
        let empty = WriteConcern()

        // test behavior of a client with initialized with no WC
        do {
            let client = try SyncMongoClient()
            let clientDesc = "client created with no WC provided"
            // expect the readConcern property to exist and be default
            try checkWriteConcern(client, empty, clientDesc)

            // expect that a DB created from this client inherits its default WC
            let db1 = client.db(type(of: self).testDatabase)
            try checkWriteConcern(db1, empty, "db created with no WC provided from \(clientDesc)")

            // expect that a DB created from this client can override the client's default WC
            let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(writeConcern: w2))
            try checkWriteConcern(db2, w2, "db created with w:2 from \(clientDesc)")
        }

        // test behavior of a client with w: 1
        do {
            let client = try SyncMongoClient(options: ClientOptions(writeConcern: w1))
            let clientDesc = "client created with w:1"
            // although w:1 is default, if it is explicitly provided it should be set
            try checkWriteConcern(client, w1, clientDesc)

            // expect that a DB created from this client inherits its WC
            let db1 = client.db(type(of: self).testDatabase)
            try checkWriteConcern(db1, w1, "db created with no WC provided from \(clientDesc)")

            // expect that a DB created from this client can override the client's WC
            let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(writeConcern: w2))
            try checkWriteConcern(db2, w2, "db created with w:2 from \(clientDesc)")
        }

        // test behavior of a client with w: 2
        do {
            let client = try SyncMongoClient(options: ClientOptions(writeConcern: w2))
            let clientDesc = "client created with w:2"
            try checkWriteConcern(client, w2, clientDesc)

            // expect that a DB created from this client can override the client's WC with an unset one
            let db = client.db(
                    type(of: self).testDatabase,
                    options: DatabaseOptions(writeConcern: empty))
            try checkWriteConcern(db, empty, "db created with empty WC from \(clientDesc)")
        }
    }

    func testDatabaseReadConcern() throws {
        let client = try SyncMongoClient.makeTestClient()
        let empty = ReadConcern()
        let local = ReadConcern(.local)
        let localString = ReadConcern("local")
        let unknown = ReadConcern("blah")
        let majority = ReadConcern(.majority)

        let db1 = client.db(type(of: self).testDatabase)
        defer { try? db1.drop() }

        let dbDesc = "db created with no RC provided"

        let coll1Name = self.getCollectionName(suffix: "1")
        // expect that a collection created from a DB with unset RC also has unset RC
        var coll1 = try db1.createCollection(coll1Name)
        try checkReadConcern(coll1, empty, "collection created with no RC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with unset RC also has unset RC
        coll1 = db1.collection(coll1Name)
        try checkReadConcern(coll1, empty, "collection retrieved with no RC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with unset RC can override the DB's RC
        let coll2 = db1.collection(self.getCollectionName(suffix: "2"), options: CollectionOptions(readConcern: local))
        try checkReadConcern(coll2, local, "collection retrieved with local RC from \(dbDesc)")

        // test with string init
        var coll3 = db1.collection(
                self.getCollectionName(suffix: "3"),
                options: CollectionOptions(readConcern: localString)
        )
        try checkReadConcern(coll3, local, "collection created with local RC string from \(dbDesc)")

        // test with unknown level
        coll3 = db1.collection(self.getCollectionName(suffix: "3"), options: CollectionOptions(readConcern: unknown))
        try checkReadConcern(coll3, unknown, "collection retrieved with unknown RC level from \(dbDesc)")

        try db1.drop()

        let db2 = client.db(
                type(of: self).testDatabase,
                options: DatabaseOptions(readConcern: local))
        defer { try? db2.drop() }

        let coll4Name = self.getCollectionName(suffix: "4")
        // expect that a collection created from a DB with local RC also has local RC
        var coll4 = try db2.createCollection(coll4Name)
        try checkReadConcern(coll4, local, "collection created with no RC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with local RC also has local RC
        coll4 = db2.collection(coll4Name)
        try checkReadConcern(coll4, local, "collection retrieved with no RC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with local RC can override the DB's RC
        let coll5 = db2.collection(
                self.getCollectionName(suffix: "5"),
                options: CollectionOptions(readConcern: majority)
        )
        try checkReadConcern(coll5, majority, "collection retrieved with majority RC from \(dbDesc)")
    }

    func testDatabaseWriteConcern() throws {
        let client = try SyncMongoClient.makeTestClient()

        let empty = WriteConcern()
        let w1 = try WriteConcern(w: .number(1))
        let w2 = try WriteConcern(w: .number(2))

        let db1 = client.db(type(of: self).testDatabase)
        defer { try? db1.drop() }

        var dbDesc = "db created with no WC provided"

        // expect that a collection created from a DB with default WC also has default WC
        var coll1 = try db1.createCollection(self.getCollectionName(suffix: "1"))
        try checkWriteConcern(coll1, empty, "collection created with no WC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with default WC also has default WC
        coll1 = db1.collection(coll1.name)
        try checkWriteConcern(coll1, empty, "collection retrieved with no WC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with default WC can override the DB's WC
        var coll2 = db1.collection(self.getCollectionName(suffix: "2"), options: CollectionOptions(writeConcern: w1))
        try checkWriteConcern(coll2, w1, "collection retrieved with w:1 from \(dbDesc)")

        try db1.drop()

        let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(writeConcern: w1))
        defer { try? db2.drop() }
        dbDesc = "db created with w:1"

        // expect that a collection created from a DB with w:1 also has w:1
        var coll3 = try db2.createCollection(self.getCollectionName(suffix: "3"))
        try checkWriteConcern(coll3, w1, "collection created with no WC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with w:1 also has w:1
        coll3 = db2.collection(coll3.name)
        try checkWriteConcern(coll3, w1, "collection retrieved with no WC provided from \(dbDesc)")

        // expect that a collection retrieved from a DB with w:1 can override the DB's WC
        let coll4 = db2.collection(self.getCollectionName(suffix: "4"), options: CollectionOptions(writeConcern: w2))
        try checkWriteConcern(coll4, w2, "collection retrieved with w:2 from \(dbDesc)")
    }

    func testOperationReadConcerns() throws {
        // setup a collection
        let client = try SyncMongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName())

        let command: Document = ["count": coll.name]

        // run command with a valid readConcern
        let options1 = RunCommandOptions(readConcern: ReadConcern(.local))
        let res1 = try db.runCommand(command, options: options1)
        expect((res1["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        // run command with an empty readConcern
        let options2 = RunCommandOptions(readConcern: ReadConcern())
        let res2 = try db.runCommand(command, options: options2)
        expect((res2["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        // running command with an invalid RC level should throw
        let options3 = RunCommandOptions(readConcern: ReadConcern("blah"))
        // error code 9: FailedToParse
        expect(try db.runCommand(command, options: options3))
                .to(throwError(ServerError.commandError(code: 9,
                                                        codeName: "FailedToParse",
                                                        message: "",
                                                        errorLabels: nil)))

        // try various command + read concern pairs to make sure they work
        expect(try coll.find(options: FindOptions(readConcern: ReadConcern(.local)))).toNot(throwError())

        expect(try coll.aggregate([["$project": ["a": 1] as Document]],
                                  options: AggregateOptions(readConcern: ReadConcern(.majority)))).toNot(throwError())

        expect(try coll.count(options: CountOptions(readConcern: ReadConcern(.majority)))).toNot(throwError())

        expect(try coll.distinct(fieldName: "a",
                                 options: DistinctOptions(readConcern: ReadConcern(.local)))).toNot(throwError())
    }

    func testWriteConcernErrors() throws {
        // Because the error codes differ between sharded clusters and replica sets for the same command (and the
        // sharded error is pretty gross), we just skip the sharded clusters. Also, a WriteConcernError isn't
        // encountered on standalones, so we skip those as well.
        guard MongoSwiftTestCase.topologyType == .replicaSetWithPrimary else {
            print(unsupportedTopologyMessage(testName: self.name))
            return
        }

        let wc = try WriteConcern(w: .number(100))
        let expectedWCError =
                WriteConcernError(code: 100, codeName: "", details: nil, message: "")
        let expectedWriteError =
                ServerError.writeError(writeError: nil, writeConcernError: expectedWCError, errorLabels: nil)
        let expectedBulkResult = BulkWriteResult(insertedCount: 1, insertedIds: [0: 1])
        let expectedBulkError = ServerError.bulkWriteError(writeErrors: [],
                                                           writeConcernError: expectedWCError,
                                                           otherError: nil,
                                                           result: expectedBulkResult,
                                                           errorLabels: nil)

        let client = try SyncMongoClient.makeTestClient()
        let database = client.db(type(of: self).testDatabase)
        let collection = database.collection(self.getCollectionName())
        defer { try? collection.drop() }

        expect(try collection.insertOne(["x": 1], options: InsertOneOptions(writeConcern: wc)))
                .to(throwError(expectedWriteError))

        expect(try collection.bulkWrite([.insertOne(["_id": 1])], options: BulkWriteOptions(writeConcern: wc)))
                .to(throwError(expectedBulkError))
    }

    func testOperationWriteConcerns() throws {
        let client = try SyncMongoClient.makeTestClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }

        var counter = 0
        func nextDoc() -> Document {
            defer { counter += 1 }
            return ["x": counter]
        }

        let coll = try db.createCollection(self.getCollectionName())
        let wc1 = try WriteConcern(w: .number(1))
        let wc2 = WriteConcern()
        let wc3 = try WriteConcern(journal: true)

        let command: Document = ["insert": coll.name, "documents": [nextDoc()] as [Document]]

        // run command with a valid writeConcern
        let options1 = RunCommandOptions(writeConcern: wc1)
        let res1 = try db.runCommand(command, options: options1)
        expect((res1["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        // run command with an empty writeConcern
        let options2 = RunCommandOptions(writeConcern: wc2)
        let res2 = try db.runCommand(command, options: options2)
        expect((res2["ok"] as? BSONNumber)?.doubleValue).to(bsonEqual(1.0))

        expect(try coll.insertOne(nextDoc(), options: InsertOneOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.insertOne(nextDoc(), options: InsertOneOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.insertMany([nextDoc(), nextDoc()],
                                   options: InsertManyOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.insertMany([nextDoc(), nextDoc()],
                                   options: InsertManyOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.updateOne(filter: ["x": 1],
                                  update: ["$set": nextDoc()],
                                  options: UpdateOptions(writeConcern: wc2))).toNot(throwError())
        expect(try coll.updateOne(filter: ["x": 2],
                                  update: ["$set": nextDoc()],
                                  options: UpdateOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.updateMany(filter: ["x": 3],
                                   update: ["$set": nextDoc()],
                                   options: UpdateOptions(writeConcern: wc2))).toNot(throwError())
        expect(try coll.updateMany(filter: ["x": 4],
                                   update: ["$set": nextDoc()],
                                   options: UpdateOptions(writeConcern: wc3))).toNot(throwError())

        let coll2 = try db.createCollection(self.getCollectionName(suffix: "2"))
        defer { try? coll2.drop() }
        let pipeline: [Document] = [["$out": "\(db.name).\(coll2.name)"]]
        expect(try coll.aggregate(pipeline, options: AggregateOptions(writeConcern: wc1))).toNot(throwError())

        expect(try coll.replaceOne(filter: ["x": 5],
                                   replacement: nextDoc(),
                                   options: ReplaceOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.replaceOne(filter: ["x": 6],
                                   replacement: nextDoc(),
                                   options: ReplaceOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.deleteOne(["x": 7], options: DeleteOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.deleteOne(["x": 8], options: DeleteOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.deleteMany(["x": 9], options: DeleteOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.deleteMany(["x": 10], options: DeleteOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.createIndex(["x": 1],
                                    options: CreateIndexOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.createIndexes([IndexModel(keys: ["x": -1])],
                                      options: CreateIndexOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.dropIndex(["x": 1], options: DropIndexOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.dropIndexes(options: DropIndexOptions(writeConcern: wc3))).toNot(throwError())
    }

    func testConnectionStrings() throws {
        let csPath = "\(MongoSwiftTestCase.specsPath)/read-write-concern/tests/connection-string"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: csPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            let testFilePath = URL(fileURLWithPath: "\(csPath)/\(filename)")
            let asDocument = try Document(fromJSONFile: testFilePath)
            let tests: [Document] = try asDocument.get("tests")
            for test in tests {
                let description: String = try test.get("description")
                // skipping because C driver does not comply with these; see CDRIVER-2621
                if description.lowercased().contains("wtimeoutms") { continue }
                let uri: String = try test.get("uri")
                let valid: Bool = try test.get("valid")
                if valid {
                    let client = try SyncMongoClient(uri)
                    if let readConcern = test["readConcern"] as? Document {
                        let rc = ReadConcern(readConcern)
                        if rc.isDefault {
                            expect(client.readConcern).to(beNil())
                        } else {
                            expect(client.readConcern).to(equal(rc))
                        }
                    } else if let writeConcern = test["writeConcern"] as? Document {
                        let wc = try WriteConcern(writeConcern)
                        if wc.isDefault {
                            expect(client.writeConcern).to(beNil())
                        } else {
                            expect(client.writeConcern).to(equal(wc))
                        }
                    }
                } else {
                    expect(try SyncMongoClient(uri)).to(throwError(UserError.invalidArgumentError(message: "")))
                }
            }
        }
    }

    func testDocuments() throws {
        let encoder = BSONEncoder()
        let docsPath = "\(MongoSwiftTestCase.specsPath)/read-write-concern/tests/document"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: docsPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            let testFilePath = URL(fileURLWithPath: "\(docsPath)/\(filename)")
            let asDocument = try Document(fromJSONFile: testFilePath)
            let tests: [Document] = try asDocument.get("tests")
            for test in tests {
                let valid: Bool = try test.get("valid")
                if let rcToUse = test["readConcern"] as? Document {
                    let rc = ReadConcern(rcToUse)

                    let isDefault: Bool = try test.get("isServerDefault")
                    expect(rc.isDefault).to(equal(isDefault))

                    let expected: Document = try test.get("readConcernDocument")
                    if expected == [:] {
                        expect(try encoder.encode(rc)).to(beNil())
                    } else {
                        expect(try encoder.encode(rc)).to(equal(expected))
                    }
                } else if let wcToUse = test["writeConcern"] as? Document {
                    if valid {
                        let wc = try WriteConcern(wcToUse)

                        let isAcknowledged: Bool = try test.get("isAcknowledged")
                        expect(wc.isAcknowledged).to(equal(isAcknowledged))

                        let isDefault: Bool = try test.get("isServerDefault")
                        expect(wc.isDefault).to(equal(isDefault))

                        var expected: Document = try test.get("writeConcernDocument")
                        if expected == [:] {
                            expect(try encoder.encode(wc)).to(beNil())
                        } else {
                            if let wtimeoutMS = expected["wtimeout"] as? BSONNumber {
                                expected["wtimeout"] = wtimeoutMS.int64Value!
                            }
                            expect(try encoder.encode(wc)).to(sortedEqual(expected))
                        }
                    } else {
                        expect(try WriteConcern(wcToUse)).to(throwError(UserError.invalidArgumentError(message: "")))
                    }
                }
            }
        }
    }
}
