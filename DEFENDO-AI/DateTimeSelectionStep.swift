import SwiftUI

struct DateTimeSelectionStep: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    var showValidationError: Bool
    var onDateOrTimeChanged: () -> Void
    var onBack: () -> Void
    var onNext: () -> Void
    var canProceed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Select Date & Time")
                .font(.headline)

            DatePicker("Select a Date", selection: $selectedDate, displayedComponents: .date)
                .onChange(of: selectedDate) { _ in onDateOrTimeChanged() }
                .datePickerStyle(GraphicalDatePickerStyle())

            DatePicker("Select a Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .onChange(of: selectedTime) { _ in onDateOrTimeChanged() }
                .datePickerStyle(WheelDatePickerStyle())

            if showValidationError {
                Text("Please select a future date and time.")
                    .foregroundColor(.red)
            }

            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button(action: onNext) {
                    Text("Next").bold()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed)
            }
        }
        .padding()
    }
}
