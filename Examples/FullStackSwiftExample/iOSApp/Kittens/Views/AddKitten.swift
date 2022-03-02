import Models
import SwiftUI

/// View to support adding a new kitten.
struct AddKitten: View {
    /// Model for the data in this view.
    @ObservedObject private var viewModel: AddKittenViewModel
    /// Presentation mode environment key. This is used to enable the view to dismiss itself on button presses.
    @Environment(\.presentationMode) private var presentationMode

    init(viewModel: AddKittenViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $viewModel.name)
                TextField("Color", text: $viewModel.color)
                Picker("Favorite Food", selection: $viewModel.favoriteFood) {
                    ForEach(CatFood.allCases) { food in
                        Text(food.rawValue.capitalized)
                    }
                }
            }
        }
        HStack {
            Button("Add Kitten") {
                viewModel.addAction {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                presentationMode.wrappedValue.dismiss()
            }
        }.buttonStyle(.bordered)
    }
}
