import Foundation
import XCTest

extension XCTestCase {

    /// Measure the time for a single execution of operation
    func measureTime(_ operation: () throws -> Void) throws -> Double {
        let startTime = ProcessInfo.processInfo.systemUptime
        try operation()
        let timeElapsed = ProcessInfo.processInfo.systemUptime - startTime
        return Double(timeElapsed)
    }

    /// Measure the median time for iterations executions of operation
    func measureOp(_ operation: () throws -> Void, iterations: Int = 100) throws -> Double {
        var results = [Double]()
        for _ in 1...iterations {
            results.append(try measureTime(operation))
        }
        return median(results)
    }

    /// Compute the median of an array of doubles 
    func median(_ input: [Double]) -> Double {
        return input.sorted(by: <)[input.count / 2]
    }

    func printResults(time: Double, size: Double) {
        let roundedTime = Double(floor(time * 1000) / 1000)
        let roundedScore = Double(floor(size / time * 10000) / 10000)
        print("Results for \(self.name): median time \(roundedTime) seconds, score \(roundedScore) MB/s")
    }

    class func getSpecsPath() -> String {
        // if we can access the "/Tests" directory, assume we're running from command line
        if FileManager.default.fileExists(atPath: "./Tests") { return "./Tests/Specs/benchmarking/data" }
        // otherwise we're in Xcode, get the bundle's resource path
        guard let path = Bundle(for: BsonBenchmarkTests.self).resourcePath else {
            XCTFail("Missing resource path")
            return ""
        }
        return path + "/benchmarking/data"
    }
}
