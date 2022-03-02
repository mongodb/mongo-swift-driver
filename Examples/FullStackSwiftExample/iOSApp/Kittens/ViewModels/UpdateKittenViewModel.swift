import Foundation
import SwiftBSON
import SwiftUI

final class UpdateDeleteKittenViewModel: ObservableObject {
    @Published var favoriteFood: CatFood
    let kitten: Kitten
    @Published var color: String

    init(currentKitten: Kitten) {
        self.kitten = currentKitten
        self.favoriteFood = currentKitten.favoriteFood
        self.color = currentKitten.color
    }

    func updateKitten() async throws {
        let url = baseURL.appendingPathComponent("kittens").appendingPathComponent(self.kitten.name)
        let kittenUpdate = KittenUpdate(favoriteFood: favoriteFood, lastUpdateTime: Date())
        try await HTTPClient.shared.sendData(to: url, object: kittenUpdate, httpMethod: .PATCH)
    }

    func updateAction(completion: @escaping () -> Void) {
        Task {
            do {
                try await updateKitten()
            } catch {
                print("ERROR9: \(error)")
            }
            completion()
        }
    }
}
