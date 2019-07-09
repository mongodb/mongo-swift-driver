import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class ChangeStreamTest: MongoSwiftTestCase {
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
        var replyPtr = UnsafeMutablePointer<BSONPointer?>.allocate(capacity: 1)
        defer {
            replyPtr.deinitialize(count: 1)
            replyPtr.deallocate()
        }

        var error = bson_error_t()
        mongoc_cursor_error_document(changeStreamPtr, &error, replyPtr)
        print(extractMongoError(error: error))
        let decoder = BSONDecoder()
        //expect(try ChangeStream<ChangeStreamDocument<Document>>(stealing: changeStreamPtr!, client: client, session: session, decoder: decoder)).toNot(throwError())
    }
}
