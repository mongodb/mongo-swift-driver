// Generated using Sourcery 0.16.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


// Re-export various types from MongoSwift that are also used in the API for MongoSwiftSync. We start out with all of
// the types in MongoSwift, and then filter out types that are not public, that are explicitly annotated with
// "skipSyncExport" (this is used to mark types that are async-specific) and types whose definitions are nested within
// other types. We don't need to explicitly re-export nested types as re-exporting their parent types will make them
// available under their parents' namespaces, just as they are in the async module.

@_exported import struct MongoSwift.AggregateOptions
@_exported import struct MongoSwift.AuthenticationError
@_exported import enum MongoSwift.BSON
@_exported import struct MongoSwift.BSONCoderOptions
@_exported import class MongoSwift.BSONDecoder
@_exported import class MongoSwift.BSONEncoder
@_exported import enum MongoSwift.BSONType
@_exported import struct MongoSwift.Binary
@_exported import struct MongoSwift.BulkWriteFailure
@_exported import struct MongoSwift.BulkWriteOptions
@_exported import struct MongoSwift.BulkWriteResult
@_exported import struct MongoSwift.ChangeStreamEvent
@_exported import struct MongoSwift.ChangeStreamOptions
@_exported import struct MongoSwift.ClientOptions
@_exported import class MongoSwift.ClientSession
@_exported import struct MongoSwift.ClientSessionOptions
@_exported import struct MongoSwift.Code
@_exported import struct MongoSwift.CodeWithScope
@_exported import struct MongoSwift.CollectionOptions
@_exported import struct MongoSwift.CollectionSpecification
@_exported import struct MongoSwift.CollectionSpecificationInfo
@_exported import enum MongoSwift.CollectionType
@_exported import struct MongoSwift.CommandError
@_exported import struct MongoSwift.CommandFailedEvent
@_exported import struct MongoSwift.CommandStartedEvent
@_exported import struct MongoSwift.CommandSucceededEvent
@_exported import struct MongoSwift.CompatibilityError
@_exported import struct MongoSwift.ConnectionError
@_exported import struct MongoSwift.ConnectionId
@_exported import struct MongoSwift.CountDocumentsOptions
@_exported import struct MongoSwift.CreateCollectionOptions
@_exported import struct MongoSwift.CreateIndexOptions
@_exported import enum MongoSwift.CursorType
@_exported import struct MongoSwift.DBPointer
@_exported import enum MongoSwift.DataCodingStrategy
@_exported import struct MongoSwift.DatabaseOptions
@_exported import struct MongoSwift.DatabaseSpecification
@_exported import enum MongoSwift.DateCodingStrategy
@_exported import struct MongoSwift.Decimal128
@_exported import struct MongoSwift.DeleteModelOptions
@_exported import struct MongoSwift.DeleteOptions
@_exported import struct MongoSwift.DeleteResult
@_exported import struct MongoSwift.DistinctOptions
@_exported import struct MongoSwift.Document
@_exported import class MongoSwift.DocumentIterator
@_exported import class MongoSwift.DocumentStorage
@_exported import struct MongoSwift.DropCollectionOptions
@_exported import struct MongoSwift.DropDatabaseOptions
@_exported import struct MongoSwift.DropIndexOptions
@_exported import struct MongoSwift.EstimatedDocumentCountOptions
@_exported import struct MongoSwift.FindOneAndDeleteOptions
@_exported import struct MongoSwift.FindOneAndReplaceOptions
@_exported import struct MongoSwift.FindOneAndUpdateOptions
@_exported import struct MongoSwift.FindOneOptions
@_exported import struct MongoSwift.FindOptions
@_exported import enum MongoSwift.FullDocument
@_exported import enum MongoSwift.Hint
@_exported import struct MongoSwift.IndexModel
@_exported import struct MongoSwift.IndexOptions
@_exported import struct MongoSwift.InsertManyResult
@_exported import struct MongoSwift.InsertOneOptions
@_exported import struct MongoSwift.InsertOneResult
@_exported import struct MongoSwift.InternalError
@_exported import struct MongoSwift.InvalidArgumentError
@_exported import struct MongoSwift.ListCollectionsOptions
@_exported import struct MongoSwift.LogicError
@_exported import struct MongoSwift.MongoNamespace
@_exported import struct MongoSwift.ObjectId
@_exported import enum MongoSwift.OperationType
@_exported import struct MongoSwift.ReadConcern
@_exported import class MongoSwift.ReadPreference
@_exported import struct MongoSwift.RegularExpression
@_exported import struct MongoSwift.ReplaceOneModelOptions
@_exported import struct MongoSwift.ReplaceOptions
@_exported import struct MongoSwift.ResumeToken
@_exported import enum MongoSwift.ReturnDocument
@_exported import struct MongoSwift.RunCommandOptions
@_exported import struct MongoSwift.ServerClosedEvent
@_exported import struct MongoSwift.ServerDescription
@_exported import struct MongoSwift.ServerDescriptionChangedEvent
@_exported import struct MongoSwift.ServerHeartbeatFailedEvent
@_exported import struct MongoSwift.ServerHeartbeatStartedEvent
@_exported import struct MongoSwift.ServerHeartbeatSucceededEvent
@_exported import struct MongoSwift.ServerOpeningEvent
@_exported import struct MongoSwift.ServerSelectionError
@_exported import struct MongoSwift.Symbol
@_exported import struct MongoSwift.TLSOptions
@_exported import struct MongoSwift.Timestamp
@_exported import struct MongoSwift.TopologyClosedEvent
@_exported import struct MongoSwift.TopologyDescription
@_exported import struct MongoSwift.TopologyDescriptionChangedEvent
@_exported import struct MongoSwift.TopologyOpeningEvent
@_exported import enum MongoSwift.UUIDCodingStrategy
@_exported import struct MongoSwift.UpdateDescription
@_exported import struct MongoSwift.UpdateModelOptions
@_exported import struct MongoSwift.UpdateOptions
@_exported import struct MongoSwift.UpdateResult
@_exported import struct MongoSwift.WriteConcern
@_exported import struct MongoSwift.WriteConcernFailure
@_exported import struct MongoSwift.WriteError
@_exported import struct MongoSwift.WriteFailure
@_exported import enum MongoSwift.WriteModel

// Protocols are not included in the types list, so we list them separately here.
@_exported import protocol MongoSwift.CodingStrategyProvider
@_exported import protocol MongoSwift.LabeledError
@_exported import protocol MongoSwift.MongoCommandEvent
@_exported import protocol MongoSwift.MongoError
@_exported import protocol MongoSwift.MongoEvent
@_exported import protocol MongoSwift.RuntimeError
@_exported import protocol MongoSwift.ServerError
@_exported import protocol MongoSwift.UserError

// Manually add typealiases
@_exported import typealias MongoSwift.InsertManyOptions
@_exported import typealias MongoSwift.ServerErrorCode
