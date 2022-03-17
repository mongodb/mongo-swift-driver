import Models
import SwiftUI

/// Main view displaying a list of kittens.
struct KittenList: View {
    /// Model for the data in this view.
    @StateObject private var viewModel = KittenListViewModel()

    @State private var showingAddModal = false
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                    List {
                        ForEach(viewModel.kittens) { kitten in
                            // Each element in the list is a link that, if clicked, will open the view/update/delete
                            // view for the corresponding kitten.
                            NavigationLink(
                                destination: ViewUpdateDeleteKitten(
                                    viewModel: ViewUpdateDeleteKittenViewModel(currentKitten: kitten)
                                )
                            ) {
                                Text(kitten.name)
                                    .font(.title3)
                            }
                        }
                    }
                    // Pull to refresh
                    .refreshable { fetchKittens() }
                    Button("Add Kitten") {
                        showingAddModal.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
                if busy {
                    ProgressView()
                }
            }
            .sheet(
                isPresented: $showingAddModal,
                onDismiss: {
                    // On dismiss, retrieve an updated list of kittens.
                    fetchKittens()
                }
            ) {
                AddKitten(viewModel: AddKittenViewModel())
            }
            // When the view appears, retrieve an updated list of kittens.
            .onAppear(perform: fetchKittens)
            .navigationBarTitle("Kittens 🐱🐱", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func fetchKittens() {
        self.busy = true
        self.errorMessage = nil
        Task {
            do {
                try await viewModel.fetchKittens()
                busy = false
            } catch {
                busy = false
                errorMessage = "Failed to fetch list of kittens: \(error.localizedDescription)"
            }
        }
    }
}

struct KittenList_Previews: PreviewProvider {
    static var previews: some View {
        KittenList()
    }
}
