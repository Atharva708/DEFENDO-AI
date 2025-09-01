//
// BookingFlowView.swift
// DEFENDO-AI
//

import SwiftUI
import UserNotifications
import Supabase
import Adapty

struct BookingFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var currentStep = 0
    @State private var selectedService: ServiceType = .securityGuard
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedDuration = 4
    @State private var location = ""
    @State private var specialInstructions = ""
    @State private var isProcessingPayment = false
    @State private var selectedPaymentMethod: String = "Card"

    @State private var showPaymentError = false
    @State private var paymentErrorMessage: String? = nil
    @State private var showPaywall = false

    let steps = ["Select Service", "Date & Time", "Duration & Location", "Confirm & Pay"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ProgressBarView(currentStep: currentStep, steps: steps)
                    .padding()

                TabView(selection: $currentStep) {
                    ServiceSelectionView(selectedService: $selectedService)
                        .tag(0)
                    DateTimeSelectionView(selectedDate: $selectedDate, selectedTime: $selectedTime)
                        .tag(1)
                    DurationLocationView(selectedDuration: $selectedDuration, location: $location, specialInstructions: $specialInstructions)
                        .tag(2)
                    ConfirmPaymentView(
                        selectedService: selectedService,
                        selectedDate: selectedDate,
                        selectedTime: selectedTime,
                        selectedDuration: selectedDuration,
                        location: location,
                        selectedPaymentMethod: $selectedPaymentMethod
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                HStack {
                    if currentStep > 0 {
                        Button(action: { withAnimation { currentStep -= 1 } }) {
                            Text("Back")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Spacer()

                    Button(action: {
                        if currentStep < 3 {
                            withAnimation { currentStep += 1 }
                        } else {
                            if isProcessingPayment { return }
                            isProcessingPayment = true
                            showPaywall = true
                        }
                    }) {
                        if isProcessingPayment {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Processing...")
                            }
                        } else {
                            Text(currentStep == 3 ? "Pay & Confirm" : "Next")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canProceedToNextStep() || isProcessingPayment)
                }
                .padding()
            }
            .navigationTitle("Book Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { appState.currentScreen = .dashboard }
                }
            }
            .onAppear {
                NotificationHelper.requestAuthorization()
                #if !targetEnvironment(macCatalyst)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
            .alert(isPresented: $showPaymentError) {
                Alert(title: Text("Payment Failed"),
                      message: Text(paymentErrorMessage ?? "An error occurred during payment."),
                      dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showPaywall) {
                AdaptyPaywallView(
                    paywallId: "YOUR_PAYWALL_ID_HERE",
                    onSuccess: {
                        Task { await saveBookingAfterPurchase() }
                    },
                    onError: { errorDescription in
                        isProcessingPayment = false
                        paymentErrorMessage = errorDescription
                        showPaymentError = true
                    }
                )
            }
        }
    }

    private func canProceedToNextStep() -> Bool {
        switch currentStep {
        case 0: return true
        case 1:
            let now = Date()
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year,.month,.day], from: selectedDate)
            let timeComponents = calendar.dateComponents([.hour,.minute], from: selectedTime)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            if let combinedDateTime = calendar.date(from: components) {
                return combinedDateTime > now
            }
            return false
        case 2: return selectedDuration > 0 && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3: return true
        default: return false
        }
    }

    private func saveBookingAfterPurchase() async {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year,.month,.day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour,.minute], from: selectedTime)
        startComponents.hour = timeComponents.hour
        startComponents.minute = timeComponents.minute
        let startTime = calendar.date(from: startComponents) ?? selectedDate
        let endTime = calendar.date(byAdding: .hour, value: selectedDuration, to: startTime) ?? startTime
        let userId = authService.currentUser?.id ?? "mock-user-id"
        let providerId = "provider-id-1"

        let bookingData = BookingData(
            id: UUID().uuidString,
            userId: userId,
            providerId: providerId,
            serviceType: selectedService,
            date: selectedDate,
            startTime: startTime,
            endTime: endTime,
            durationHours: selectedDuration,
            location: location,
            latitude: nil as Double?,
            longitude: nil as Double?,
            status: .pending,
            price: calculateTotalPrice(),
            userNotes: specialInstructions
        )

        let saved = await saveBookingToSupabase(bookingData: bookingData)
        DispatchQueue.main.async {
            isProcessingPayment = false
            showPaywall = false
            if saved {
                NotificationHelper.scheduleBookingConfirmedNotification(for: bookingData)
                appState.currentScreen = .dashboard
            } else {
                paymentErrorMessage = "Failed to save your booking. Please try again."
                showPaymentError = true
            }
        }
    }

    private func calculateTotalPrice() -> Double {
        let hourlyRate = selectedService == .securityGuard ? 25.0 : 35.0
        return hourlyRate * Double(selectedDuration)
    }

    private func saveBookingToSupabase(bookingData: BookingData) async -> Bool {
        do {
            try await SupabaseService.shared.createBooking(bookingData)
            return true
        } catch {
            print("Supabase error: \(error)")
            return false
        }
    }
}

// -----------------------------
// Include all views like ProgressBarView, ServiceSelectionView, DateTimeSelectionView, DurationLocationView, ConfirmPaymentView, AdaptyPaywallView, PrimaryButtonStyle, SecondaryButtonStyle
// without redeclaring Booking, BookingData, ServiceType, BookingStatus
// -----------------------------

// ----------- PLACEHOLDERS --------------

import SwiftUI

struct ProgressBarView: View {
    let currentStep: Int
    let steps: [String]
    var body: some View {
        HStack {
            ForEach(0..<steps.count, id: \.self) { idx in
                Circle()
                    .fill(idx <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct ServiceSelectionView: View {
    @Binding var selectedService: ServiceType
    var body: some View {
        VStack {
            Text("Select Service View")
            Text("Selected: \(selectedService.rawValue)")
        }
    }
}

struct DateTimeSelectionView: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    var body: some View {
        VStack {
            Text("Date/Time Selection View")
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
        }
    }
}

struct DurationLocationView: View {
    @Binding var selectedDuration: Int
    @Binding var location: String
    @Binding var specialInstructions: String
    var body: some View {
        VStack {
            Text("Duration & Location View")
            Stepper("Duration: \(selectedDuration) hours", value: $selectedDuration, in: 1...24)
            TextField("Location", text: $location)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Special Instructions", text: $specialInstructions)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
}

struct ConfirmPaymentView: View {
    let selectedService: ServiceType
    let selectedDate: Date
    let selectedTime: Date
    let selectedDuration: Int
    let location: String
    @Binding var selectedPaymentMethod: String
    var body: some View {
        VStack {
            Text("Confirm and Pay View")
            Text("Service: \(selectedService.rawValue)")
            Text("Date: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
            Text("Time: \(selectedTime.formatted(date: .omitted, time: .shortened))")
            Text("Duration: \(selectedDuration) hours")
            Text("Location: \(location)")
            Picker("Payment Method", selection: $selectedPaymentMethod) {
                Text("Card").tag("Card")
                Text("Apple Pay").tag("Apple Pay")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
    }
}

struct AdaptyPaywallView: View {
    let paywallId: String
    let onSuccess: () -> Void
    let onError: (String) -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text("Paywall Placeholder for \(paywallId)")
            Button("Simulate Purchase Success") { onSuccess() }
            Button("Simulate Error") { onError("Simulated payment error") }.foregroundColor(.red)
        }
        .padding()
    }
}

struct NotificationHelper {
    static func requestAuthorization() {
        // Placeholder: Add UNUserNotificationCenter logic here
    }
    static func scheduleBookingConfirmedNotification(for booking: Any) {
        // Placeholder: Schedule booking notification
    }
}
// ----------- END PLACEHOLDERS -----------
