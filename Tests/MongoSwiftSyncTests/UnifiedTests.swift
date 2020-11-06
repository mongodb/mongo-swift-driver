import Nimble
import TestsCommon

final class UnifiedRunnerTests: MongoSwiftTestCase {
    func testSchemaVersion() {
        let oneTwoThree = SchemaVersion(rawValue: "1.2.3")
        expect(oneTwoThree).toNot(beNil())
        expect(oneTwoThree?.major).to(equal(1))
        expect(oneTwoThree?.minor).to(equal(2))
        expect(oneTwoThree?.patch).to(equal(3))

        // no patch provided
        let oneTwo = SchemaVersion(rawValue: "1.2")
        expect(oneTwo).toNot(beNil())
        expect(oneTwo?.major).to(equal(1))
        expect(oneTwo?.minor).to(equal(2))
        expect(oneTwo?.patch).to(equal(0))

        // no minor provided
        let one = SchemaVersion(rawValue: "1")
        expect(one).toNot(beNil())
        expect(one?.major).to(equal(1))
        expect(one?.minor).to(equal(0))
        expect(one?.patch).to(equal(0))

        // invalid inputs
        let inputs = [
            "a",
            "1.2.3.4",
            ""
        ]

        for input in inputs {
            expect(SchemaVersion(rawValue: input)).to(beNil())
        }
    }

    func testUnifiedTestDecoding() throws {
        expect(try retrieveSpecTestFiles(
            specName: "unified-test-format",
            subdirectory: "valid-pass",
            asType: UnifiedTestFile.self
        )).toNot(throwError())
    }
}
