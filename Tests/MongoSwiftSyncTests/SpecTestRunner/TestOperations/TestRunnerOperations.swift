import MongoSwiftSync
import Nimble
import TestsCommon

struct AssertCollectionExists: TestOperation {
    let database: String
    let collection: String

    func execute<T: SpecTest>(on runner: inout T, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        let client = try MongoClient.makeTestClient()
        let collectionNames = try client.db(self.database).listCollectionNames()
        expect(collectionNames).to(contain(self.collection), description: runner.description)
        return nil
    }
}

struct AssertCollectionNotExists: TestOperation {
    let database: String
    let collection: String

    func execute<T: SpecTest>(on runner: inout T, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        let client = try MongoClient.makeTestClient()
        let collectionNames = try client.db(self.database).listCollectionNames()
        expect(collectionNames).toNot(contain(self.collection), description: runner.description)
        return nil
    }
}

struct AssertIndexExists: TestOperation {
    let database: String
    let collection: String
    let index: String

    func execute<T: SpecTest>(on _: inout T, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        let client = try MongoClient.makeTestClient()
        let indexNames = try client.db(self.database).collection(self.collection).listIndexNames()
        expect(indexNames).to(contain(self.index))
        return nil
    }
}

struct AssertIndexNotExists: TestOperation {
    let database: String
    let collection: String
    let index: String

    func execute<T: SpecTest>(on _: inout T, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        let client = try MongoClient.makeTestClient()
        let indexNames = try client.db(self.database).collection(self.collection).listIndexNames()
        expect(indexNames).toNot(contain(self.index))
        return nil
    }
}

struct AssertSessionPinned: TestOperation {
    let session: String

    func execute<T: SpecTest>(on _: inout T, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let session = sessions[self.session] else {
            throw TestError(message: "active session not provided to assertSessionPinned")
        }
        expect(session.isPinned).to(beTrue(), description: "expected \(self.session) to be pinned but it wasn't")
        return nil
    }
}

struct AssertSessionUnpinned: TestOperation {
    let session: String

    func execute<T: SpecTest>(on _: inout T, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let session = sessions[self.session] else {
            throw TestError(message: "active session not provided to assertSessionUnpinned")
        }
        expect(session.isPinned).to(beFalse(), description: "expected \(self.session) to be unpinned but it wasn't")
        return nil
    }
}

struct AssertSessionTransactionState: TestOperation {
    let session: String?
    let state: ClientSession.TransactionState

    func execute<T: SpecTest>(on _: inout T, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let transactionState = sessions[self.session ?? ""]?.transactionState else {
            throw TestError(message: "active session not provided to assertSessionTransactionState")
        }
        expect(transactionState).to(equal(self.state))
        return nil
    }
}

struct TargetedFailPoint: TestOperation {
    let session: String
    let failPoint: FailPoint

    func execute<T: SpecTest>(on runner: inout T, sessions: [String: ClientSession]) throws -> TestOperationResult? {
        guard let session = sessions[self.session], let server = session.pinnedServerAddress else {
            throw TestError(message: "could not get session or session not pinned to mongos")
        }
        try runner.activateFailPoint(self.failPoint, on: server)
        return nil
    }
}
