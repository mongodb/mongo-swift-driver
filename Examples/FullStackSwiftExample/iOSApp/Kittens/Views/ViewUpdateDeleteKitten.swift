import Models
import SwiftUI

/// View to support viewing information about and updating or deleting a kitten.
struct ViewUpdateDeleteKitten: View {
    /// Model for the data in this view.
    @ObservedObject private var viewModel: ViewUpdateDeleteKittenViewModel
    /// Presentation mode environment key. This is used to enable the view to dismiss itself on button presses.
    @Environment(\.presentationMode) private var presentationMode

    init(viewModel: ViewUpdateDeleteKittenViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            NavigationView {
                Form {
                    Section {
                        HStack {
                            Text("Last Updated").frame(alignment: .leading)
                            Spacer()
                            Text(viewModel.kitten.lastUpdateTime, style: .relative).frame(alignment: .trailing)
                        }
                        HStack {
                            Text("Color").frame(alignment: .leading)
                            Spacer()
                            Text(viewModel.kitten.color.capitalized).frame(alignment: .trailing)
                        }
                        Picker("Favorite Food", selection: $viewModel.favoriteFood) {
                            ForEach(CatFood.allCases) { food in
                                Text(food.rawValue.capitalized)
                            }
                        }
                    }
                }.navigationTitle(Text(viewModel.kitten.name))
            }
            HStack {
                Button("Save Changes") {
                    viewModel.updateAction {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Button("Delete Kitten", role: .destructive) {
                    viewModel.deleteAction {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Button("Close", role: .cancel) {
                    presentationMode.wrappedValue.dismiss()
                }
            }.buttonStyle(.bordered)
        }
    }
}
