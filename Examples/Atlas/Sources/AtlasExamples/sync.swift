import Foundation
import MongoSwiftSync

/// Atlas connection string examples
/// Please include the above imports in the snippet.

func syncScramExample() throws {
    // START SCRAM EXAMPLE HERE
    let client = try MongoClient(
        "mongodb+srv://<user>:<password>@<host>/<dbname>?retryWrites=true&w=majority"
    )
    defer {
        cleanupMongoSwift()
    }

    let db = client.db("library")
    let collection = db.collection("books")
    // do something with collection
    // END SCRAM EXAMPLE HERE
}

func syncX509Example() throws {
    // START x509 EXAMPLE HERE
    let options = MongoClientOptions(
        credential: MongoCredential(mechanism: .mongodbX509),
        tlsCAFile: URL(string: "/path/to/cert"),
        tlsCertificateKeyFile: URL(string: "/path/to/cert")
    )
    let client = try MongoClient(
        "mongodb+srv://<host>/<dbname>?retryWrites=true&w=majority",
        options: options
    )
    defer {
        cleanupMongoSwift()
    }

    let db = client.db("library")
    let collection = db.collection("books")
    // do something with collection
    // END x509 EXAMPLE HERE
}
