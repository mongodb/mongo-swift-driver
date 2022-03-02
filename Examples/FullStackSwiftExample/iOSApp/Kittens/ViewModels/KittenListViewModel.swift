import Models
import SwiftUI

/// Models the data used in the `KittenList` view.
class KittenListViewModel: ObservableObject {
    /// The list of kittens to display.
    @Published var kittens = [Kitten]()

    /// Loads an updated list of kittens from the backend server.
    func fetchKittens() async throws {
        let kittens = try await HTTP.get(url: HTTP.baseURL, dataType: [Kitten].self)
        // we do this on the main queue so that when the value is updated the view will automatically be refreshed.
        DispatchQueue.main.async {
            self.kittens = kittens
        }
    }
}
