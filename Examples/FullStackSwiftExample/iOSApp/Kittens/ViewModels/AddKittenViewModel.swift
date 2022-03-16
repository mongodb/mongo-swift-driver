import Models
import SwiftUI

/// Models the data used in the `AddKitten` view.
class AddKittenViewModel: ObservableObject {
    /// New kitten name (initially, an empty string).
    @Published var name = ""
    /// New kitten color (initially, an empty string).
    @Published var color = ""
    /// New kitten favorite food. We have to display some initial value, so use chicken to start.
    @Published var favoriteFood: CatFood = .chicken

    /// Sends a request to add a new kitten to the backend.
   func addKitten() async throws {
        let kitten = Kitten(name: name, color: color, favoriteFood: favoriteFood)
        try await HTTP.post(url: HTTP.baseURL, body: kitten)
    }
}
