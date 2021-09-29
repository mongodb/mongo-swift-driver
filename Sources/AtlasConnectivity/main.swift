import Foundation
import MongoSwiftSync

private let configs = ["ATLAS_REPL", "ATLAS_SHRD", "ATLAS_FREE", "ATLAS_TLS11", "ATLAS_TLS12", "ATLAS_SERVERLESS"]
private let srvConfigs = configs.map { $0 + "_SRV" }

for config in configs + srvConfigs {
    print("Testing config \(config)... ", terminator: "")

    guard let uri = ProcessInfo.processInfo.environment[config] else {
        print("Failed: couldn't find URI for config \(config)")
        exit(1)
    }

    do {
        let client = try MongoClient(uri)
        let db = client.db("test")
        _ = try db.runCommand(["hello": 1])

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
