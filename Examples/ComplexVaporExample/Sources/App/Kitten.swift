import Foundation
import MongoSwift
import Vapor

/// Possible cat food choices.
enum CatFood: String, Codable {
    case salmon,
        tuna,
        chicken,
        turkey,
        beef
}

/// The structure of a food update request.
struct FoodUpdate: Codable {
    let favoriteFood: CatFood
}

/// Represents a kitten.
struct Kitten: Content {
    /// Unique identifier.
    var _id: BSONObjectID?
    /// Name.
    let name: String
    /// Fur color.
    let color: String
    /// Favorite food.
    let favoriteFood: CatFood
}

/// Context struct for the index page.
struct IndexContext: Encodable {
    let kittens: [Kitten]
}
