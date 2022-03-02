import Models
import SwiftUI

/// Main view displaying a list of kittens.
struct KittenList: View {
    /// Model for the data in this view.
    @StateObject private var viewModel = KittenListViewModel()
    /// The type of modal currently being displayed.
    @State private var modalType: ModalType?

    /// Represents the types of modals that can be accessed from this view.
    /// This type conforms to `Identifiable` so that it can be used as a binding for the sheet view.
    private enum ModalType: Identifiable {
        var id: String {
            switch self {
            case .add: return "add"
            case .viewUpdateDelete: return "viewUpdateDelete"
            }
        }

        /// Modal to add a new kitten.
        case add
        /// Modal to view, update, or delete the associated `Kitten` object,
        case viewUpdateDelete(Kitten)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.kittens) { kitten in
                    // Each element in the list is a button that, if clicked, will open the view/update/delete view for
                    // the corresponding kitten.
                    Button {
                        modalType = .viewUpdateDelete(kitten)
                    } label: {
                        Text(kitten.name)
                            .font(.title3)
                            .foregroundColor(Color(.label))
                    }
                }
            }
            .navigationTitle("Kittens 🐱🐱")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        // When the modal type changes to a non-nil value, present a sheet using the corresponding view.
        .sheet(
            item: $modalType,
            onDismiss: {
                // On dismiss, unset the modal type and retrieve an updated list of kittens.
                modalType = nil
                runInTask {
                    try await viewModel.fetchKittens()
                }
            }
        ) { modal in
            switch modal {
            case .add:
                AddKitten(viewModel: AddKittenViewModel())
            case let .viewUpdateDelete(kitten):
                ViewUpdateDeleteKitten(viewModel: ViewUpdateDeleteKittenViewModel(currentKitten: kitten))
            }
        }
        .onAppear {
            // When the view appears, retrieve an updated list of kittens.
            runInTask {
                try await viewModel.fetchKittens()
            }
        }
        Button("Add Kitten") {
            modalType = .add
        }.buttonStyle(.bordered)
    }
}
