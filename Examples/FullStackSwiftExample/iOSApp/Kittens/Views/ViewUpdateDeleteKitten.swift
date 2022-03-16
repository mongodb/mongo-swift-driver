import Models
import SwiftBSON
import SwiftUI

/// View to support viewing information about and updating or deleting a kitten.
struct ViewUpdateDeleteKitten: View {
    /// Model for the data in this view.
    @ObservedObject var viewModel: ViewUpdateDeleteKittenViewModel
    /// Presentation mode environment key. This is used to enable the view to dismiss itself on button presses.
    @Environment(\.presentationMode) private var presentationMode

    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VStack {
                Form {
                    Section {
                        HStack {
                            Text("Last Updated").frame(alignment: .leading)
                            Spacer()
                            Text(viewModel.kitten.lastUpdateTime, style: .relative)
                        }
                        HStack {
                            Text("Color").frame(alignment: .leading)
                            Spacer()
                            Text(viewModel.kitten.color.capitalized)
                        }
                        Picker("Favorite Food", selection: $viewModel.favoriteFood) {
                            ForEach(CatFood.allCases) { food in
                                Text(food.rawValue.capitalized)
                            }
                        }
                    }
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                HStack {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Delete Kitten", role: .destructive) {
                        deleteKitten()
                    }
                    .buttonStyle(.bordered)
                    Button("Close", role: .cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            if busy {
                ProgressView()
            }
        }
        .navigationBarTitle(viewModel.kitten.name, displayMode: .inline)
    }

    private func deleteKitten() {
        self.busy = true
        self.errorMessage = nil
        Task {
            do {
                try await viewModel.deleteKitten()
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = "Failed to delete kitten: \(error.localizedDescription)"
                busy = false
            }
        }
    }

    private func saveChanges() {
        self.busy = true
        self.errorMessage = nil
        Task {
            do {
                try await viewModel.updateKitten()
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
                busy = false
            }
        }
    }
}

struct ViewUpdateDeleteKitten_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ViewUpdateDeleteKitten(
                viewModel: ViewUpdateDeleteKittenViewModel(
                    currentKitten: Kitten(name: "Roscoe", color: "orange", favoriteFood: .salmon)
                )
            )
        }
    }
}
