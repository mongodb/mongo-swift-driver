import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class ChangeStream: MongoSwiftTestCase {
    func testChangeStream() throws {
        let encoder = BSONEncoder()
        let client = try MongoClient()
        let session = try client.startSession()
        let db = client.db("myDb")
        let coll = db.collection("myColl")
        let options = ChangeStreamOptions()
        let opts = try encodeOptions(options: options, session: session)
        let pipeline: Document = []

        let changeStreamPtr = mongoc_collection_watch(coll._collection, pipeline._bson, opts?._bson)
        let decoder = BSONDecoder()
        expect(try ChangeStream(changeStreamPtr, client: client, session: session, decoder: decoder, withType: Document.self)).toNot(throwError())
    }
}
