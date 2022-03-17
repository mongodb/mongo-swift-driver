import Models
import SwiftUI

/// Models the data used in the `ViewUpdateDeleteKitten` view.
class ViewUpdateDeleteKittenViewModel: ObservableObject {
    /// The kitten's favorite food. This is mutable as the form allows the user to update this value.
    @Published var favoriteFood: CatFood
    /// The initial kitten this view is created with.
    let kitten: Kitten

    init(currentKitten: Kitten) {
        self.kitten = currentKitten
        self.favoriteFood = currentKitten.favoriteFood
    }

    /// Sends a request to update this kitten to the backend.
    func updateKitten() async throws {
        // if the selected food didn't change we don't need to do anything.
        guard self.favoriteFood != self.kitten.favoriteFood else {
            return
        }
        let kittenUpdate = KittenUpdate(newFavoriteFood: favoriteFood)
        try await HTTP.patch(url: self.kitten.resourceURL, body: kittenUpdate)
    }

    /// Sends a request to delete this kitten to the backend.
    func deleteKitten() async throws {
        try await HTTP.delete(url: self.kitten.resourceURL)
    }
}
