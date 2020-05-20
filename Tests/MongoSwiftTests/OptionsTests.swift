import Foundation
import MongoSwift
import Nimble
import TestsCommon

final class OptionsTests: MongoSwiftTestCase {
    let allOptionsStructs: [Any] = [
        BSONCoderOptions(),
        ChangeStreamOptions(),
        ClientSessionOptions(),
        MongoClientOptions(),
        DatabaseOptions(),
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
        FindOneOptions(),
        InsertOneOptions(),
        UpdateOptions(),
        ReplaceOptions(),
        DeleteOptions(),
        DropCollectionOptions(),
        CollectionOptions(),
        DropDatabaseOptions(),
        CreateCollectionOptions(),
        CreateIndexOptions(),
        DistinctOptions(),
        DropIndexOptions(),
        ListCollectionsOptions(),
        RunCommandOptions(),
        CountDocumentsOptions(),
        EstimatedDocumentCountOptions(),
        TransactionOptions()
    ]

    // This will be useful with Swift 5.1 auto-generated initializers (see SWIFT-622)
    func testOptionsAlphabeticalOrder() throws {
        for options in self.allOptionsStructs {
            let mirror = Mirror(reflecting: options)
            let labels = mirror.children.map { $0.label! }
            expect(labels.sorted()).to(equal(labels), description: "\(type(of: options))")
        }
    }
}
