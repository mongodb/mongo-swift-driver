import MongoSwift
import Nimble
import NIO
import TestsCommon

extension WriteConcern {
    /// Initialize a new `WriteConcern` from a `Document`. We can't
    /// use `decode` because the format is different in spec tests
    /// ("journal" instead of "j", etc.)
    fileprivate init(_ doc: BSONDocument) throws {
        let j = doc["journal"]?.boolValue

        var w: W?
        if let str = doc["w"]?.stringValue {
            w = str == "majority" ? .majority : .custom(str)
        } else if let wInt = doc["w"]?.toInt() {
            w = .number(wInt)
        }

        let wt = doc["wtimeoutMS"]?.toInt()

        try self.init(journal: j, w: w, wtimeoutMS: wt)
    }
}

class ReadWriteConcernSpecTests: MongoSwiftTestCase {
    func testConnectionStrings() throws {
        // we have to create this directly so we can use the MongoClient initializer that takes a uri
        let testElg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { testElg.syncShutdownOrFail() }

        let testFiles = try retrieveSpecTestFiles(
            specName: "read-write-concern",
            subdirectory: "connection-string",
            asType: BSONDocument.self
        )
        for (_, asDocument) in testFiles {
            let tests: [BSONDocument] = asDocument["tests"]!.arrayValue!.compactMap { $0.documentValue }
            for test in tests {
                let uri = test["uri"]!.stringValue!
                let valid = test["valid"]!.boolValue!
                if valid {
                    let client = try MongoClient(uri, using: testElg)
                    defer { client.syncCloseOrFail() }

                    if let readConcern = test["readConcern"]?.documentValue {
                        let rc = try BSONDecoder().decode(ReadConcern.self, from: readConcern)
                        if rc.isDefault {
                            expect(client.readConcern).to(beNil())
                        } else {
                            expect(client.readConcern).to(equal(rc))
                        }
                    } else if let writeConcern = test["writeConcern"]?.documentValue {
                        let wc = try WriteConcern(writeConcern)
                        if wc.isDefault {
                            expect(client.writeConcern).to(beNil())
                        } else {
                            expect(client.writeConcern).to(equal(wc))
                        }
                    }
                } else {
                    expect(try MongoClient(uri, using: testElg))
                        .to(throwError(errorType: MongoError.InvalidArgumentError.self))
                }
            }
        }
    }

    func testDocuments() throws {
        let encoder = BSONEncoder()
        let testFiles = try retrieveSpecTestFiles(
            specName: "read-write-concern",
            subdirectory: "document",
            asType: BSONDocument.self
        )

        for (_, asDocument) in testFiles {
            let tests = asDocument["tests"]!.arrayValue!.compactMap { $0.documentValue }
            for test in tests {
                let valid: Bool = test["valid"]!.boolValue!
                if let rcToUse = test["readConcern"]?.documentValue {
                    let rc = try BSONDecoder().decode(ReadConcern.self, from: rcToUse)

                    let isDefault = test["isServerDefault"]!.boolValue!
                    expect(rc.isDefault).to(equal(isDefault))

                    let expected = test["readConcernDocument"]!.documentValue!
                    if expected == [:] {
                        expect(try encoder.encode(rc)).to(beNil())
                    } else {
                        expect(try encoder.encode(rc)).to(equal(expected))
                    }
                } else if let wcToUse = test["writeConcern"]?.documentValue {
                    if valid {
                        let wc = try WriteConcern(wcToUse)

                        let isAcknowledged = test["isAcknowledged"]!.boolValue!
                        expect(wc.isAcknowledged).to(equal(isAcknowledged))

                        let isDefault = test["isServerDefault"]!.boolValue!
                        expect(wc.isDefault).to(equal(isDefault))

                        var expected = test["writeConcernDocument"]!.documentValue!
                        if expected == [:] {
                            expect(try encoder.encode(wc)).to(beNil())
                        } else {
                            if let wtimeoutMS = expected["wtimeout"] {
                                expected["wtimeout"] = .int64(wtimeoutMS.toInt64()!)
                            }
                            expect(try encoder.encode(wc)).to(sortedEqual(expected))
                        }
                    } else {
                        expect(try WriteConcern(wcToUse))
                            .to(throwError(errorType: MongoError.InvalidArgumentError.self))
                    }
                }
            }
        }
    }
}
