import Foundation
import MongoSwiftSync

private let configs = ["ATLAS_REPL", "ATLAS_SHRD", "ATLAS_FREE", "ATLAS_TLS11", "ATLAS_TLS12"]

for config in configs {
    print("Testing config \(config)... ", terminator: "")

    guard let uri = ProcessInfo.processInfo.environment[config] else {
        print("Failed: couldn't find URI")
        exit(1)
    }

    do {
        let client = try MongoClient(uri)
        // run isMaster
        let db = client.db("test")
        _ = try db.runCommand(["isMaster": 1])
        // findOne
        let coll = db.collection("test")
        _ = try coll.findOne()
    } catch {
        print("Failed: \(error)")
        exit(1)
    }

    print("Success")
}

print("All tests passed")
