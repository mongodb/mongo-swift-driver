import Foundation
import MongoSwift
import Vapor

/// Represents a kitten.
struct Kitten: Content {
    /// Unique identifier.
    var _id: BSONObjectID?
    /// Name.
    let name: String
    /// Date of birth.
    let birthdate: Date
    /// Fur length.
    let furLength: FurLength
    /// Fur color.
    let color: String

}

/// Represents possible fur lengths.
enum FurLength: String, Codable {
    case short, medium, long
}
