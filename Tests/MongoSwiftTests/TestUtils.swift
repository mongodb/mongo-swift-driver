import Foundation
import XCTest

extension XCTestCase {
	/// Gets the path of the directory containing spec files, depending on whether
	/// we're running from XCode or the command line
	func getSpecsPath() -> String {
        // if we can access the "/Tests" directory, assume we're running from command line
        if FileManager.default.fileExists(atPath: "./Tests") { return "./Tests/Specs" }
        // otherwise we're in Xcode, get the bundle's resource path
        guard let path = Bundle(for: type(of: self)).resourcePath else {
            XCTFail("Missing resource path")
            return ""
        }
        return path
    }
}
