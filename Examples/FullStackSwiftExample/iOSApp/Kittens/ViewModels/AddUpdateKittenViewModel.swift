import Foundation
import SwiftBSON
import SwiftUI

final class AddKittenViewModel: ObservableObject {
    @Published var kittenName = ""

    var kittenID: BSONObjectID?

    var isUpdating: Bool {
        self.kittenID != nil
    }

    var buttonTitle: String {
        self.kittenID != nil ? "Update Kitten" : "Add Kitten"
    }

    init() {}

    init(currentKitten: Kitten) {
        self.kittenName = currentKitten.name
        self.kittenID = currentKitten.id
    }

    func addKitten() async throws {
        let kitten = Kitten(id: nil, name: kittenName, color: "white", favoriteFood: .chicken, lastUpdateTime: Date())
        try await HTTPClient.shared.sendData(to: baseURL, object: kitten, httpMethod: .POST)
    }

    func updateKitten() async throws {
        let url = baseURL.appendingPathComponent(self.kittenName)
        let kittenUpdate = KittenUpdate(favoriteFood: .turkey, lastUpdateTime: Date())
        try await HTTPClient.shared.sendData(to: url, object: kittenUpdate, httpMethod: .PATCH)
    }

    func addUpdateAction(completion: @escaping () -> Void) {
        Task {
            do {
                if isUpdating {
                    try await updateKitten()
                } else {
                    try await addKitten()
                }
            } catch {
                print("ERROR1: \(error)")
            }
            completion()
        }
    }
}
