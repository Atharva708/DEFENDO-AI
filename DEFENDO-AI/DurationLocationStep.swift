import SwiftUI

struct DurationLocationStep: View {
    @Binding var selectedDuration: Int
    @Binding var location: String
    @Binding var specialInstructions: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Duration & Location")
                .font(.headline)

            Stepper(value: $selectedDuration, in: 1...24) {
                Text("Duration: \(selectedDuration) hour\(selectedDuration == 1 ? "" : "s")")
            }

            TextField("Enter location/address", text: $location)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Special instructions (optional)", text: $specialInstructions)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
}
