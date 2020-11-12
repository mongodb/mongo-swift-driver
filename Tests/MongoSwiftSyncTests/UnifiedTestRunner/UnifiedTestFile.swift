import MongoSwiftSync
import TestsCommon

/// Structure representing a test file in the unified test format.
struct UnifiedTestFile: Decodable {
    /// The name of the test file.
    let description: String

    /// Version of this specification with which the test file complies.
    let schemaVersion: SchemaVersion

    /// Optional array of one or more version/topology test requirements.  If no requirements are met, the test runner
    /// MUST skip this test file.
    let runOnRequirements: [TestRequirement]?

    /// Optional array of one or more entity objects (e.g. client, collection, session objects) that SHALL be created
    /// before each test case is executed.
    let createEntities: [EntityDescription]?

    /// Optional array of one or more collectionData objects. Data that will exist in collections before each test case
    /// is executed.
    let initialData: [CollectionData]?

    /// Required array of one or more test objects. List of test cases to be executed independently of each other.
    let tests: [UnifiedTest]
}

/// List of documents corresponding to the contents of a collection.
struct CollectionData: Decodable {
    /// The name of a collection.
    let collectionName: String

    /// The name of a database.
    let databaseName: String

    /// List of documents corresponding to the contents of the collection. May be empty.
    let documents: [BSONDocument]
}

/// Represents a single test in a test file.
struct UnifiedTest: Decodable {
    /// The name of the test.
    let description: String

    /// Optional array of one or more runOnRequirement objects. List of server version and/or topology requirements for
    /// which this test can be run. If specified, these requirements are evaluated independently and in addition to any
    /// top-level runOnRequirements. If no requirements in this array are met, the test runner MUST skip this test.
    let runOnRequirements: [TestRequirement]?

    /// Optional string. If set, the test will be skipped.
    let skipReason: String?

    /// Array of one or more operation objects. List of operations to be executed for the test case.
    let operations: [UnifiedOperation]

    /// Optional array of one or more expectedEventsForClient objects. For one or more clients, a list of events that
    /// are expected to be observed in a particular order.
    let expectEvents: [ExpectedEventsForClient]?

    /// Data that is expected to exist in collections after the test case is executed.
    let outcome: [CollectionData]?
}
