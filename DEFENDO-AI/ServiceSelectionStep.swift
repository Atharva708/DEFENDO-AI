import SwiftUI

struct ServiceSelectionStep: View {
    @Binding var selectedService: ServiceType

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Service Type")
                .font(.headline)

            Picker("Service", selection: $selectedService) {
                ForEach(ServiceType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
    }
}
