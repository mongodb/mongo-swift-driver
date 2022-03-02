import SwiftUI

struct AddKitten: View {
    @ObservedObject var viewModel: AddKittenViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            TextField("kitten name", text: $viewModel.kittenName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button {
                viewModel.addUpdateAction {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                Text(viewModel.buttonTitle)
            }
        }
    }
}

struct AddUpdateKitten_Previews: PreviewProvider {
    static var previews: some View {
        AddUpdateKitten(viewModel: AddKittenViewModel())
    }
}
