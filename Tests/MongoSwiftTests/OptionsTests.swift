import Foundation
@testable import MongoSwift
import Nimble
import XCTest

final class OptionsTests: MongoSwiftTestCase {
    let allOptionsStructs: [Any] = [
        BSONCoderOptions(),
        ChangeStreamOptions(),
        ClientSessionOptions(),
        ClientOptions(),
        DatabaseOptions(),
        TLSOptions(),
        DeleteModelOptions(),
        ReplaceOneModelOptions(),
        UpdateModelOptions(),
        BulkWriteOptions(),
        FindOneAndDeleteOptions(),
        FindOneAndReplaceOptions(),
        FindOneAndUpdateOptions(),
        IndexOptions(),
        AggregateOptions(),
        FindOptions(),
        InsertOneOptions(),
        UpdateOptions(),
        ReplaceOptions(),
        DeleteOptions(),
        DropCollectionOptions(),
        CollectionOptions(),
        DropDatabaseOptions(),
        CountOptions(),
        CreateCollectionOptions(),
        CreateIndexOptions(),
        DistinctOptions(),
        DropIndexOptions(),
        ListCollectionsOptions(),
        RunCommandOptions()
    ]

    // This will be useful with Swift 5.1 auto-generated initializers
    func testOptionsAlphabeticalOrder() throws {
        for options in self.allOptionsStructs {
            let mirror = Mirror(reflecting: options)
            let labels = mirror.children.map { $0.label! }
            expect(labels.sorted()).to(equal(labels), description: "\(type(of: options))")
        }
    }
}
