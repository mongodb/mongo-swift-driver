// Generated using Sourcery 1.3.4 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// Re-export the BSON library
@_exported import SwiftBSON

// Re-export various types from MongoSwift that are also used in the API for MongoSwiftSync. We start out with all of
// the types in MongoSwift, and then filter out types that are not public, that are explicitly annotated with
// "skipSyncExport" (this is used to mark types that are async-specific) and types whose definitions are nested within
// other types. We don't need to explicitly re-export nested types as re-exporting their parent types will make them
// available under their parents' namespaces, just as they are in the async module.

@_exported import struct MongoSwift.AggregateOptions
@_exported import struct MongoSwift.BulkWriteOptions
@_exported import struct MongoSwift.BulkWriteResult
@_exported import struct MongoSwift.ChangeStreamEvent
@_exported import struct MongoSwift.ChangeStreamOptions
@_exported import struct MongoSwift.ClientSessionOptions
@_exported import struct MongoSwift.CollectionSpecification
@_exported import struct MongoSwift.CollectionSpecificationInfo
@_exported import enum MongoSwift.CollectionType
@_exported import enum MongoSwift.CommandEvent
@_exported import struct MongoSwift.CommandFailedEvent
@_exported import struct MongoSwift.CommandStartedEvent
@_exported import struct MongoSwift.CommandSucceededEvent
@_exported import struct MongoSwift.Compressor
@_exported import struct MongoSwift.CountDocumentsOptions
@_exported import struct MongoSwift.CreateCollectionOptions
@_exported import struct MongoSwift.CreateIndexOptions
@_exported import struct MongoSwift.DatabaseSpecification
@_exported import struct MongoSwift.DeleteModelOptions
@_exported import struct MongoSwift.DeleteOptions
@_exported import struct MongoSwift.DeleteResult
@_exported import struct MongoSwift.DistinctOptions
@_exported import struct MongoSwift.DropCollectionOptions
@_exported import struct MongoSwift.DropDatabaseOptions
@_exported import struct MongoSwift.DropIndexOptions
@_exported import struct MongoSwift.EstimatedDocumentCountOptions
@_exported import struct MongoSwift.FindOneAndDeleteOptions
@_exported import struct MongoSwift.FindOneAndReplaceOptions
@_exported import struct MongoSwift.FindOneAndUpdateOptions
@_exported import struct MongoSwift.FindOneOptions
@_exported import struct MongoSwift.FindOptions
@_exported import struct MongoSwift.FullDocument
@_exported import enum MongoSwift.IndexHint
@_exported import struct MongoSwift.IndexModel
@_exported import struct MongoSwift.IndexOptions
@_exported import struct MongoSwift.InsertManyResult
@_exported import struct MongoSwift.InsertOneOptions
@_exported import struct MongoSwift.InsertOneResult
@_exported import struct MongoSwift.ListCollectionsOptions
@_exported import struct MongoSwift.ListDatabasesOptions
@_exported import struct MongoSwift.MongoClientOptions
@_exported import struct MongoSwift.MongoCollectionOptions
@_exported import struct MongoSwift.MongoConnectionString
@_exported import struct MongoSwift.MongoCredential
@_exported import enum MongoSwift.MongoCursorType
@_exported import struct MongoSwift.MongoDatabaseOptions
@_exported import enum MongoSwift.MongoError
@_exported import struct MongoSwift.MongoNamespace
@_exported import struct MongoSwift.MongoServerAPI
@_exported import enum MongoSwift.OperationType
@_exported import struct MongoSwift.ReadConcern
@_exported import struct MongoSwift.ReadPreference
@_exported import struct MongoSwift.RenameCollectionOptions
@_exported import struct MongoSwift.ReplaceOneModelOptions
@_exported import struct MongoSwift.ReplaceOptions
@_exported import struct MongoSwift.ResumeToken
@_exported import enum MongoSwift.ReturnDocument
@_exported import struct MongoSwift.RunCommandOptions
@_exported import enum MongoSwift.SDAMEvent
@_exported import struct MongoSwift.ServerAddress
@_exported import struct MongoSwift.ServerClosedEvent
@_exported import struct MongoSwift.ServerDescription
@_exported import struct MongoSwift.ServerDescriptionChangedEvent
@_exported import struct MongoSwift.ServerHeartbeatFailedEvent
@_exported import struct MongoSwift.ServerHeartbeatStartedEvent
@_exported import struct MongoSwift.ServerHeartbeatSucceededEvent
@_exported import struct MongoSwift.ServerOpeningEvent
@_exported import struct MongoSwift.TopologyClosedEvent
@_exported import struct MongoSwift.TopologyDescription
@_exported import struct MongoSwift.TopologyDescriptionChangedEvent
@_exported import struct MongoSwift.TopologyOpeningEvent
@_exported import struct MongoSwift.TransactionOptions
@_exported import struct MongoSwift.UpdateDescription
@_exported import struct MongoSwift.UpdateModelOptions
@_exported import struct MongoSwift.UpdateOptions
@_exported import struct MongoSwift.UpdateResult
@_exported import struct MongoSwift.WriteConcern
@_exported import enum MongoSwift.WriteModel

// Protocols are not included in the types list, so we list them separately here.
@_exported import protocol MongoSwift.CommandEventHandler
@_exported import protocol MongoSwift.MongoErrorProtocol
@_exported import protocol MongoSwift.MongoLabeledError
@_exported import protocol MongoSwift.MongoRuntimeError
@_exported import protocol MongoSwift.MongoServerError
@_exported import protocol MongoSwift.MongoUserError
@_exported import protocol MongoSwift.SDAMEventHandler

// Manually add typealiases
@_exported import typealias MongoSwift.InsertManyOptions

// Manually add cleanup method
@_exported import func MongoSwift.cleanupMongoSwift
