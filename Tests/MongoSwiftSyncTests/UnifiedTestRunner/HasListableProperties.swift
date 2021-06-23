import MongoSwiftSync

protocol HasListableProperties {
    var propertyNames: [String] { get }
}

extension HasListableProperties {
    var propertyNames: [String] {
        Mirror(reflecting: self).children.map { $0.label! }
    }
}

extension BulkWriteOptions: HasListableProperties {}
extension FindOneAndReplaceOptions: HasListableProperties {}
extension FindOneAndUpdateOptions: HasListableProperties {}
extension FindOneAndDeleteOptions: HasListableProperties {}
extension DeleteOptions: HasListableProperties {}
extension ReplaceOptions: HasListableProperties {}
extension EstimatedDocumentCountOptions: HasListableProperties {}
extension InsertOneOptions: HasListableProperties {}
extension DeleteModelOptions: HasListableProperties {}
extension UpdateModelOptions: HasListableProperties {}
extension UpdateOptions: HasListableProperties {}
extension ReplaceOneModelOptions: HasListableProperties {}
extension ChangeStreamOptions: HasListableProperties {}
