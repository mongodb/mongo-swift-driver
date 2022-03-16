import Models
import SwiftUI

/// View to support adding a new kitten.
struct AddKitten: View {
    /// Model for the data in this view.
    @ObservedObject var viewModel: AddKittenViewModel
    /// Presentation mode environment key. This is used to enable the view to dismiss itself on button presses.
    @Environment(\.presentationMode) private var presentationMode

    @State private var errorMessage: String?
    @State private var busy = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Form {
                        TextField("Name", text: $viewModel.name)
                        TextField("Color", text: $viewModel.color)
                        Picker("Favorite Food", selection: $viewModel.favoriteFood) {
                            ForEach(CatFood.allCases) { food in
                                Text(food.rawValue.capitalized)
                            }
                        }
                    }
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                    HStack {
                        Button("Add Kitten") {
                            addKitten()
                        }
                        .disabled(viewModel.name.isEmpty)
                        .buttonStyle(.borderedProminent)
                        Button("Cancel", role: .cancel) {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                if busy {
                    ProgressView()
                }
            }
        }
    }

    private func addKitten() {
        self.errorMessage = nil
        self.busy = true
        Task {
            do {
                try await viewModel.addKitten()
                presentationMode.wrappedValue.dismiss()
            } catch {
                errorMessage = "Failed to add kitten: \(error.localizedDescription)"
                busy = false
            }
        }
    }
}

struct AddKitten_Previews: PreviewProvider {
    static var previews: some View {
        AddKitten(viewModel: AddKittenViewModel())
    }
}
