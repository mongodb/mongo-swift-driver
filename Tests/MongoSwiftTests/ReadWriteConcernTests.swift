@testable import MongoSwift
import Nimble
import XCTest

extension WriteConcern {
    /// Initialize a new `WriteConcern` from a `Document`. We can't
    /// use `decode` because the format is different in spec tests
    /// ("journal" instead of "j", etc.)
    fileprivate convenience init(_ doc: Document) throws {
        let j = doc["journal"] as? Bool

        var w: W?
        if let wtag = doc["w"] as? String {
            w = wtag == "majority" ? .majority : .tag(wtag)
        } else if let wInt = doc["w"] as? Int {
            w = .number(Int32(wInt))
        }

        var wt: Int32?
        if let wtInt = doc["wtimeoutMS"] as? Int {
            wt = Int32(wtInt)
        }

        try self.init(journal: j, w: w, wtimeoutMS: wt)
    }
}

final class ReadWriteConcernTests: MongoSwiftTestCase {
    override func setUp() {
        self.continueAfterFailure = false
    }

    func testReadConcernType() throws {
        // check level var works as expected
        let rc = ReadConcern(.majority)
        expect(rc.level).to(equal("majority"))

        // test copy init
        let rc2 = ReadConcern(from: rc)
        expect(rc2.level).to(equal("majority"))

        // test empty init
        let rc3 = ReadConcern()
        expect(rc3.level).to(beNil())

        // test init from doc
        let rc4 = ReadConcern(["level": "majority"])
        expect(rc4.level).to(equal("majority"))
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
    }

    func testClientReadConcern() throws {
        let majority = ReadConcern(.majority)

        // test behavior of a client with initialized with no RC
        do {
            let client = try MongoClient()
            // expect the readConcern property to exist with a nil level
            expect(client.readConcern).to(beNil())

            // expect that a DB created from this client inherits its unset RC 
            let db1 = client.db(type(of: self).testDatabase)
            expect(db1.readConcern).to(beNil())

            // expect that a DB created from this client can override the client's unset RC
            let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: majority))
            expect(db2.readConcern?.level).to(equal("majority"))
        }

        // test behavior of a client initialized with local RC
        do {
            let client = try MongoClient(options: ClientOptions(readConcern: ReadConcern(.local)))
            // although local is default, if it is explicitly provided it should be set
            expect(client.readConcern?.level).to(equal("local"))

            // expect that a DB created from this client inherits its local RC 
            let db1 = client.db(type(of: self).testDatabase)
            expect(db1.readConcern?.level).to(equal("local"))

            // expect that a DB created from this client can override the client's local RC
            let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: majority))
            expect(db2.readConcern?.level).to(equal("majority"))
        }

        // test behavior of a client initialized with majority RC
        do {
            let client = try MongoClient(options: ClientOptions(readConcern: majority))
            expect(client.readConcern?.level).to(equal("majority"))

            // expect that a DB created from this client can override the client's majority RC with an unset one
            let db = client.db(type(of: self).testDatabase, options: DatabaseOptions(readConcern: ReadConcern()))
            expect(db.readConcern).to(beNil())
        }
    }

    func testClientWriteConcern() throws {
        let w1 = WriteConcern.W.number(1)
        let w2 = WriteConcern.W.number(2)
        let wc2 = try WriteConcern(w: w2)

        // test behavior of a client with initialized with no WC
        do {
            let client1 = try MongoClient()
            // expect the readConcern property to exist and be default
            expect(client1.writeConcern).to(beNil())

            // expect that a DB created from this client inherits its default WC
            let db1 = client1.db(type(of: self).testDatabase)
            expect(db1.writeConcern).to(beNil())

            // expect that a DB created from this client can override the client's default WC
            let db2 = client1.db(type(of: self).testDatabase, options: DatabaseOptions(writeConcern: wc2))
            expect(db2.writeConcern?.w).to(equal(w2))
        }

        // test behavior of a client with w: 1
        do {
            let client2 = try MongoClient(options: ClientOptions(writeConcern: WriteConcern(w: .number(1))))
            // although w:1 is default, if it is explicitly provided it should be set
            expect(client2.writeConcern?.w).to(equal(w1))

            // expect that a DB created from this client inherits its WC
            let db3 = client2.db(type(of: self).testDatabase)
            expect(db3.writeConcern?.w).to(equal(w1))

            // expect that a DB created from this client can override the client's WC
            let db4 = client2.db(type(of: self).testDatabase, options: DatabaseOptions(writeConcern: wc2))
            expect(db4.writeConcern?.w).to(equal(w2))
        }

        // test behavior of a client with w: 2
        do {
            let client3 = try MongoClient(options: ClientOptions(writeConcern: wc2))
            expect(client3.writeConcern?.w).to(equal(w2))

            // expect that a DB created from this client can override the client's WC with an unset one
            let db5 = client3.db(
                    type(of: self).testDatabase,
                    options: DatabaseOptions(writeConcern: WriteConcern()))
            expect(db5.writeConcern).to(beNil())
        }
    }

    func testDatabaseReadConcern() throws {
        let client = try MongoClient()

        let db1 = client.db(type(of: self).testDatabase)
        defer { try? db1.drop() }

        let coll1Name = self.getCollectionName(suffix: "1")
        // expect that a collection created from a DB with unset RC also has unset RC
        var coll1 = try db1.createCollection(coll1Name)
        expect(coll1.readConcern).to(beNil())

        // expect that a collection retrieved from a DB with unset RC also has unset RC
        coll1 = db1.collection(coll1Name)
        expect(coll1.readConcern).to(beNil())

        // expect that a collection retrieved from a DB with unset RC can override the DB's RC
        var coll2 = db1.collection(
                self.getCollectionName(suffix: "2"),
                options: CollectionOptions(readConcern: ReadConcern(.local))
        )
        expect(coll2.readConcern?.level).to(equal("local"))

        try db1.drop()

        let db2 = client.db(
                type(of: self).testDatabase,
                options: DatabaseOptions(readConcern: ReadConcern(.local)))
        defer { try? db2.drop() }

        let coll3Name = self.getCollectionName(suffix: "3")
        // expect that a collection created from a DB with local RC also has local RC
        var coll3 = try db2.createCollection(coll3Name)
        expect(coll3.readConcern?.level).to(equal("local"))

        // expect that a collection retrieved from a DB with local RC also has local RC
        coll3 = db2.collection(coll3Name)
        expect(coll3.readConcern?.level).to(equal("local"))

        // expect that a collection retrieved from a DB with local RC can override the DB's RC
        let coll4 = db2.collection(
                self.getCollectionName(suffix: "4"),
                options: CollectionOptions(readConcern: ReadConcern(.majority))
        )
        expect(coll4.readConcern?.level).to(equal("majority"))
    }

    func testDatabaseWriteConcern() throws {
        let client = try MongoClient()

        let db1 = client.db(type(of: self).testDatabase)
        defer { try? db1.drop() }

        // expect that a collection created from a DB with default WC also has default WC
        var coll1 = try db1.createCollection(self.getCollectionName(suffix: "1"))
        expect(coll1.writeConcern).to(beNil())

        // expect that a collection retrieved from a DB with default WC also has default WC
        coll1 = db1.collection(coll1.name)
        expect(coll1.writeConcern).to(beNil())

        let wc1 = try WriteConcern(w: .number(1))
        let wc2 = try WriteConcern(w: .number(2))

        // expect that a collection retrieved from a DB with default WC can override the DB's WC
        var coll2 = db1.collection(
                self.getCollectionName(suffix: "2"),
                options: CollectionOptions(writeConcern: wc1)
        )
        expect(coll2.writeConcern?.w).to(equal(wc1.w))

        try db1.drop()

        let db2 = client.db(type(of: self).testDatabase, options: DatabaseOptions(writeConcern: wc1))
        defer { try? db2.drop() }

        // expect that a collection created from a DB with w:1 also has w:1
        var coll3 = try db2.createCollection(self.getCollectionName(suffix: "3"))
        expect(coll3.writeConcern?.w).to(equal(wc1.w))

        // expect that a collection retrieved from a DB with w:1 also has w:1
        coll3 = db2.collection(coll3.name)
        expect(coll3.writeConcern?.w).to(equal(wc1.w))

        // expect that a collection retrieved from a DB with w:1 can override the DB's WC
        let coll4 = db2.collection(
                self.getCollectionName(suffix: "4"),
                options: CollectionOptions(writeConcern: wc2))
        expect(coll4.writeConcern?.w).to(equal(wc2.w))
    }

    func testOperationReadConcerns() throws {
        // setup a collection 
        let client = try MongoClient()
        let db = client.db(type(of: self).testDatabase)
        defer { try? db.drop() }
        let coll = try db.createCollection(self.getCollectionName())

        let command: Document = ["count": coll.name]

        // run command with a valid readConcern
        let options1 = RunCommandOptions(readConcern: ReadConcern(.local))
        let res1 = try db.runCommand(command, options: options1)
        expect(res1["ok"]).to(bsonEqual(1.0))

        // run command with an empty readConcern
        let options2 = RunCommandOptions(readConcern: ReadConcern())
        let res2 = try db.runCommand(command, options: options2)
        expect(res2["ok"]).to(bsonEqual(1.0))

        // running command with an invalid RC level should throw
        let options3 = RunCommandOptions(readConcern: ReadConcern("blah"))
        // error code 9: FailedToParse
        expect(try db.runCommand(command, options: options3))
                .to(throwError(ServerError.commandError(code: 9, message: "", errorLabels: nil)))

        // try various command + read concern pairs to make sure they work
        expect(try coll.find(options: FindOptions(readConcern: ReadConcern(.local)))).toNot(throwError())

        expect(try coll.aggregate([["$project": ["a": 1] as Document]],
                                  options: AggregateOptions(readConcern: ReadConcern(.majority)))).toNot(throwError())

        expect(try coll.count(options: CountOptions(readConcern: ReadConcern(.majority)))).toNot(throwError())

        expect(try coll.distinct(fieldName: "a",
                                 options: DistinctOptions(readConcern: ReadConcern(.local)))).toNot(throwError())
    }

    func testOperationWriteConcerns() throws {
        let client = try MongoClient()
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
        expect(res1["ok"]).to(bsonEqual(1.0))

        // run command with an empty writeConcern
        let options2 = RunCommandOptions(writeConcern: wc2)
        let res2 = try db.runCommand(command, options: options2)
        expect(res2["ok"]).to(bsonEqual(1.0))

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
                                    commandOptions: CreateIndexOptions(writeConcern: wc1))).toNot(throwError())
        expect(try coll.createIndexes([IndexModel(keys: ["x": -1])],
                                      options: CreateIndexOptions(writeConcern: wc3))).toNot(throwError())

        expect(try coll.dropIndex(["x": 1], commandOptions: DropIndexOptions(writeConcern: wc1))).toNot(throwError())
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
                    let client = try MongoClient(connectionString: uri)
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
                    expect(try MongoClient(connectionString: uri))
                            .to(throwError(UserError.invalidArgumentError(message: "")))
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
                let description: String = try test.get("description")
                // skipping because C driver does not comply with these; see CDRIVER-2621
                if ["WTimeoutMS as an invalid number", "W as an invalid number"].contains(description) { continue }
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

                        let expected: Document = try test.get("writeConcernDocument")
                        if expected == [:] {
                            expect(try encoder.encode(wc)).to(beNil())
                        } else {
                            expect(try encoder.encode(wc)).to(equal(expected))
                        }
                    } else {
                        expect(try WriteConcern(wcToUse)).to(throwError(UserError.invalidArgumentError(message: "")))
                    }
                }
            }
        }
    }
}
