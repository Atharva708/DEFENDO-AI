//
// BookingFlowView.swift
// DEFENDO-AI
//

import SwiftUI
import UserNotifications
import Supabase
import Razorpay

struct BookingFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    
    @State private var currentStep = 0
    
    // Step 1
    @State private var selectedService: ServiceType = .securityGuard
    
    // Step 2
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    
    // Step 3
    @State private var selectedDuration = 4
    @State private var location = ""
    @State private var specialInstructions = ""
    
    // Step 4
    @State private var selectedPaymentMethod: PaymentMethod = .card
    
    // Payment & UI State
    @State private var isProcessingPayment = false
    @State private var paymentErrorMessage: String? = nil
    @State private var showPaymentError = false
    @State private var showBookingConfirmation = false
    
    // Show previous bookings sheet
    @State private var showPreviousBookings = false
    
    // Razorpay
    @State private var razorpay: RazorpayCheckout?
    @State private var razorpayCoordinator: RazorpayCheckoutCoordinator?
    
    let steps = ["Select Service", "Date & Time", "Duration & Location", "Confirm & Pay"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    ProgressBarView(currentStep: currentStep, steps: steps)
                        .padding(.top)
                        .padding(.horizontal)
                        .accentColor(.blue)
                    
                    Group {
                        switch currentStep {
                        case 0:
                            ServiceSelectionStep(selectedService: $selectedService)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .shadow(radius: 7, y: 2)
                                )
                                .padding(.horizontal)
                        case 1:
                            DateTimeSelectionStep(
                                selectedDate: $selectedDate,
                                selectedTime: $selectedTime,
                                showValidationError: !canProceedToNextStep(),
                                onDateOrTimeChanged: { /* trigger UI update if needed */ },
                                onBack: {
                                    withAnimation { currentStep -= 1 }
                                },
                                onNext: {
                                    withAnimation { currentStep += 1 }
                                },
                                canProceed: canProceedToNextStep()
                            )
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .shadow(radius: 7, y: 2)
                            )
                            .padding(.horizontal)
                        case 2:
                            DurationLocationStep(selectedDuration: $selectedDuration,
                                                 location: $location,
                                                 specialInstructions: $specialInstructions)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .shadow(radius: 7, y: 2)
                                )
                                .padding(.horizontal)
                        case 3:
                            ConfirmPaymentStep(
                                selectedService: selectedService,
                                selectedDate: selectedDate,
                                selectedTime: selectedTime,
                                selectedDuration: selectedDuration,
                                location: location,
                                specialInstructions: specialInstructions,
                                selectedPaymentMethod: $selectedPaymentMethod,
                                totalPrice: calculateTotalPrice()
                            )
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .shadow(radius: 7, y: 2)
                            )
                            .padding(.horizontal)
                        default:
                            EmptyView()
                        }
                    }
                    .animation(.easeInOut, value: currentStep)
                    
                    Spacer()
                    
                    // Updated bottom bar:
                    // For Step 1 and Steps >= 2 (excluding Step 2), show back/cancel/next/pay buttons here
                    
                    if currentStep == 0 || currentStep >= 2 {
                        HStack {
                            if currentStep == 1 {
                                // Removed Cancel button here (moved to navigation bar)
                            } else if currentStep > 0 {
                                Button(action: { withAnimation { currentStep -= 1 } }) {
                                    Label("Back", systemImage: "chevron.left")
                                        .fontWeight(.semibold)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .accessibilityIdentifier("backButton")
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if currentStep < 3 {
                                    withAnimation { currentStep += 1 }
                                } else {
                                    startRazorpayPayment()
                                }
                            }) {
                                if isProcessingPayment {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("Processing...")
                                            .fontWeight(.semibold)
                                    }
                                } else {
                                    Text(currentStep == 3 ? "Pay & Confirm" : "Next")
                                        .bold()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(
                                (currentStep == 1 && !canProceedToNextStep()) ||
                                (!canProceedToNextStep()) ||
                                isProcessingPayment
                            )
                            .accessibilityIdentifier("nextOrPayButton")
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Book Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != 1 {
                        Button("Cancel") {
                            appState.currentScreen = .dashboard
                        }
                        .accessibilityIdentifier("cancelButton")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPreviousBookings = true
                    } label: {
                        Label("My Bookings", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("myBookingsButton")
                }
            }
            .alert(isPresented: $showPaymentError) {
                Alert(
                    title: Text("Payment Failed"),
                    message: Text(paymentErrorMessage ?? "An error occurred during payment."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fullScreenCover(isPresented: $showBookingConfirmation, onDismiss: {
                appState.currentScreen = .dashboard
            }) {
                BookingConfirmationView(
                    serviceType: selectedService,
                    date: selectedDate,
                    time: selectedTime,
                    duration: selectedDuration,
                    location: location,
                    price: calculateTotalPrice()
                )
            }
            .sheet(isPresented: $showPreviousBookings) {
                PreviousBookingsView()
                    .environmentObject(authService)
            }
            .onAppear {
                NotificationHelper.requestAuthorization()
                #if !targetEnvironment(macCatalyst)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
                resetPaymentState()
            }
        }
    }
    
    // MARK: - Step Proceed Validation
    
    private func canProceedToNextStep() -> Bool {
        switch currentStep {
        case 0:
            // Selected service is always valid since default is set
            return true
            
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
            
        case 2:
            let locationTrimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
            return selectedDuration > 0 && !locationTrimmed.isEmpty
            
        case 3:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Payment Flow
    
    private func resetPaymentState() {
        isProcessingPayment = false
        paymentErrorMessage = nil
        showPaymentError = false
        razorpay = nil
        razorpayCoordinator = nil
    }
    
    private func startRazorpayPayment() {
        guard !isProcessingPayment else { return }
        isProcessingPayment = true
        
        let amountInPaise = Int(calculateTotalPrice() * 100) // Razorpay amount in paise (INR)
        
        // Razorpay Key ID (test)
        let razorpayKey = "rzp_test_RDymBSsTitkLdn"
        
        // TODO: The Razorpay Key Secret must be used on your backend to create and sign Razorpay orders securely.
        // Do NOT embed or use the Key Secret in this iOS app, to keep your integration secure.
        
        // Initialize coordinator with success and failure handlers
        let coordinator = RazorpayCheckoutCoordinator(
            onSuccess: {
                handleRazorpayPaymentSuccess()
            },
            onFailure: { errorMessage in
                handleRazorpayPaymentFailure(error: errorMessage)
            }
        )
        razorpayCoordinator = coordinator
        
        // Initialize Razorpay instance
        let razorpayInstance = RazorpayCheckout.initWithKey(razorpayKey, andDelegate: coordinator)
        razorpay = razorpayInstance
        
        // Prepare options dictionary
        var options: [String:Any] = [
            "amount": amountInPaise, // amount in paise
            "currency": "INR",
            "description": "\(selectedService.rawValue) service for \(selectedDuration) hour\(selectedDuration == 1 ? "" : "s")",
            "prefill": [
                "contact": "", // TODO: Add user's phone number if available
                "email": authService.currentUser?.email ?? "" // Use user email if available
            ],
            "theme": [
                "color": "#3399cc"
            ]
            ,
            "notes": [
                "qr_code_id": "qr_REBKIrPN7MM76x"
            ]
            // TODO: Add more options if needed (e.g., order_id, notes, address etc.)
        ]
        
        // Present Razorpay checkout modally from the top UIViewController
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            razorpayInstance.open(options, displayController: rootViewController)
        } else {
            // Fallback if rootViewController not found
            isProcessingPayment = false
            paymentErrorMessage = "Unable to present payment gateway."
            showPaymentError = true
        }
    }
    
    private func handleRazorpayPaymentSuccess() {
        Task {
            await saveBookingAfterPurchase()
        }
    }
    
    private func handleRazorpayPaymentFailure(error: String) {
        isProcessingPayment = false
        paymentErrorMessage = error
        showPaymentError = true
        razorpay = nil
        razorpayCoordinator = nil
    }
    
    // MARK: - Booking Save
    
    @MainActor
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
        isProcessingPayment = false
        if saved {
            NotificationHelper.scheduleBookingConfirmedNotification(for: bookingData)
            showBookingConfirmation = true
        } else {
            paymentErrorMessage = "Failed to save your booking. Please try again."
            showPaymentError = true
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

// MARK: - RazorpayCheckoutCoordinator

class RazorpayCheckoutCoordinator: NSObject, RazorpayPaymentCompletionProtocolWithData {
    let onSuccess: () -> Void
    let onFailure: (String) -> Void
    init(onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    func onPaymentSuccess(_ payment_id: String?, andData response: [AnyHashable : Any]?) {
        onSuccess()
    }
    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable : Any]?) {
        onFailure(str)
    }
}

// MARK: - PaymentMethod Enum

enum PaymentMethod: String, CaseIterable, Identifiable {
    case card = "Card"
    case applePay = "Apple Pay"
    
    var id: String { rawValue }
}

// MARK: - Step 1: Service Selection Step

struct ServiceSelectionStep: View {
    @Binding var selectedService: ServiceType
    
    struct ServiceOption: Identifiable {
        let id = UUID()
        let type: ServiceType
        let title: String
        let description: String
        let hourlyRate: Double
        let iconName: String
        let iconColor: Color
    }
    
    private let services: [ServiceOption] = [
        ServiceOption(type: .securityGuard,
                      title: "Security Guard",
                      description: "Professional guard to protect your property.",
                      hourlyRate: 25,
                      iconName: "shield.lefthalf.fill",
                      iconColor: .blue),
        ServiceOption(type: .bodyguard,
                      title: "Bodyguard",
                      description: "Personal protection by trained bodyguards.",
                      hourlyRate: 35,
                      iconName: "person.fill.checkmark",
                      iconColor: .green)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.fill")
                        .foregroundColor(.blue)
                    Text("Choose your service")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
                
                ForEach(services) { service in
                    Button(action: {
                        selectedService = service.type
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(service.type == selectedService ? service.iconColor.opacity(0.2) : Color.gray.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                Image(systemName: service.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .foregroundColor(service.type == selectedService ? service.iconColor : .gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(service.title)
                                    .font(.headline)
                                    .foregroundColor(service.type == selectedService ? .primary : .secondary)
                                Text(service.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Text("$\(Int(service.hourlyRate))/hr")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(service.type == selectedService ? .primary : .secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(service.type == selectedService ? service.iconColor : Color.gray.opacity(0.3), lineWidth: service.type == selectedService ? 2 : 1)
                                .background(service.type == selectedService ? service.iconColor.opacity(0.12) : Color.clear)
                                .cornerRadius(16)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(service.type == selectedService ? .isSelected : [])
                    .accessibilityIdentifier("serviceOption_\(service.type.rawValue)")
                }
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 2: Date & Time Selection Step (with manual time input and buttons)

struct DateTimeSelectionStep: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    
    var showValidationError: Bool = false
    var onDateOrTimeChanged: (() -> Void)? = nil
    
    var onBack: (() -> Void)
    var onNext: (() -> Void)
    var canProceed: Bool
    
    @State private var hasInteracted = false
    @State private var manualTime: String = ""
    @State private var timeFormatError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                Text("Pick Date & Time")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Group {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .labelsHidden()
                    .accessibilityIdentifier("datePicker")
                    .onChange(of: selectedDate) { newDate in
                        hasInteracted = true
                        onDateOrTimeChanged?()
                        let calendar = Calendar.current
                        if !calendar.isDateInToday(newDate) {
                            // Set selectedTime to 9 AM on the new date
                            if let nineAM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: newDate) {
                                selectedTime = nineAM
                                manualTime = formatTime(selectedTime)
                                timeFormatError = nil
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("HH:mm", text: $manualTime)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityIdentifier("manualTimeTextField")
                        .onChange(of: manualTime) { newValue in
                            hasInteracted = true
                            if let date = parseManualTime(newValue) {
                                selectedTime = date
                                timeFormatError = nil
                                onDateOrTimeChanged?()
                            } else {
                                timeFormatError = "Enter time as HH:mm (e.g., 09:30)"
                            }
                        }
                    
                    if let timeFormatError = timeFormatError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .accessibilityHidden(true)
                            Text(timeFormatError)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .accessibilityIdentifier("timeFormatError")
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            
            if showValidationError && hasInteracted && timeFormatError == nil {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    Text("Please select a future date and time.")
                        .foregroundColor(.red)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("dateTimeValidationError")
                }
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer(minLength: 0)
            
            HStack {
                Button(action: {
                    onBack()
                }) {
                    Label("Back", systemImage: "chevron.left")
                        .fontWeight(.semibold)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("backButton")
                
                Spacer()
                
                Button(action: {
                    onNext()
                }) {
                    Text("Next")
                        .bold()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed)
                .accessibilityIdentifier("nextButtonStep2")
            }
            .padding(.top, 20)
        }
        .padding(.vertical)
        .onAppear {
            manualTime = formatTime(selectedTime)
            timeFormatError = nil
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func parseManualTime(_ input: String) -> Date? {
        // Validate HH:mm 24-hour format
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = try! NSRegularExpression(pattern: #"^([01]\d|2[0-3]):([0-5]\d)$"#)
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard regex.firstMatch(in: trimmed, options: [], range: range) != nil else {
            return nil
        }
        
        let components = trimmed.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        return calendar.date(from: dateComponents)
    }
}


// MARK: - Step 3: Duration & Location Step

struct DurationLocationStep: View {
    @Binding var selectedDuration: Int
    @Binding var location: String
    @Binding var specialInstructions: String
    
    @State private var showMapPicker = false
    @State private var locationError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                        .foregroundColor(.red)
                    Text("Duration & Location")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Stepper(value: $selectedDuration, in: 1...24) {
                        Text("\(selectedDuration) hour\(selectedDuration == 1 ? "" : "s")")
                            .font(.body)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    .accessibilityIdentifier("durationStepper")
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Location")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        TextField("Enter address or location", text: $location)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .accessibilityIdentifier("locationTextField")
                            .disableAutocorrection(true)
                        
                        Button {
                            showMapPicker = true
                        } label: {
                            Label("Pick on Map", systemImage: "map")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityIdentifier("pickOnMapButton")
                    }
                    
                    if let error = locationError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .accessibilityHidden(true)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .accessibilityIdentifier("locationErrorText")
                        }
                        .padding(.bottom, 8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Special Instructions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $specialInstructions)
                        .frame(height: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .accessibilityIdentifier("specialInstructionsEditor")
                }
            }
            .padding(.top)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showMapPicker) {
            MapLocationPickerView(selectedLocation: $location, isPresented: $showMapPicker)
        }
    }
}

// MARK: - Step 4: Confirm & Pay Step

struct ConfirmPaymentStep: View {
    let selectedService: ServiceType
    let selectedDate: Date
    let selectedTime: Date
    let selectedDuration: Int
    let location: String
    let specialInstructions: String
    
    @Binding var selectedPaymentMethod: PaymentMethod
    let totalPrice: Double
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .foregroundColor(.green)
                    Text("Review & Confirm")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    infoRow(iconName: "shield.lefthalf.fill", iconColor: .blue, title: "Service", subtitle: selectedService.rawValue)
                    
                    infoRow(iconName: "calendar", iconColor: .green, title: "Date", subtitle: selectedDate.formatted(date: .long, time: .omitted))
                    
                    infoRow(iconName: "clock", iconColor: .orange, title: "Time", subtitle: selectedTime.formatted(date: .omitted, time: .shortened))
                    
                    infoRow(iconName: "hourglass", iconColor: .purple, title: "Duration", subtitle: "\(selectedDuration) hour\(selectedDuration == 1 ? "" : "s")")
                    
                    infoRow(iconName: "mappin.and.ellipse", iconColor: .red, title: "Location", subtitle: location)
                    
                    if !specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        infoRow(iconName: "text.bubble", iconColor: .gray, title: "Instructions", subtitle: specialInstructions)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
                
                // Payment Method Picker
                VStack(alignment: .leading, spacing: 16) {
                    Text("Payment Method")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            HStack {
                                Image(systemName: method == .card ? "creditcard.fill" : "applelogo")
                                Text(method.rawValue)
                            }.tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accessibilityIdentifier("paymentMethodPicker")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.tertiarySystemBackground)))
                
                // Price Breakdown
                VStack(spacing: 12) {
                    HStack {
                        Text("Hourly Rate:")
                        Spacer()
                        Text("$\(selectedService == .securityGuard ? "25" : "35")")
                    }
                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text("\(selectedDuration) hour\(selectedDuration == 1 ? "" : "s")")
                    }
                    Divider()
                    HStack {
                        Text("Total:")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "$%.2f", totalPrice))
                            .font(.headline)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
    }
    
    @ViewBuilder
    private func infoRow(iconName: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

// MARK: - MapLocationPickerView

struct MapLocationPickerView: View {
    @Binding var selectedLocation: String
    @Binding var isPresented: Bool
    
    @State private var tempLocation: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Pick Location on Map")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                // Placeholder map representation, replace with MapKit or other map integration
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .cornerRadius(16)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                            Text("Map integration coming soon")
                                .foregroundColor(.gray)
                                .font(.footnote)
                        }
                    )
                    .frame(height: 320)
                    .padding(.horizontal)
                
                TextField("Enter Address", text: $tempLocation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .accessibilityIdentifier("mapLocationTextField")
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if !tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            selectedLocation = tempLocation.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        isPresented = false
                    }
                    .disabled(tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("doneMapLocationButton")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .accessibilityIdentifier("cancelMapLocationButton")
                }
            }
            .onAppear {
                tempLocation = selectedLocation
            }
        }
    }
}

// MARK: - Booking Confirmation View

struct BookingConfirmationView: View {
    let serviceType: ServiceType
    let date: Date
    let time: Date
    let duration: Int
    let location: String
    let price: Double
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .foregroundColor(.green)
                .accessibilityHidden(true)
                .shadow(radius: 8)
            
            Text("Booking Confirmed!")
                .font(.largeTitle)
                .bold()
                .accessibilityIdentifier("bookingConfirmedTitle")
            
            VStack(alignment: .leading, spacing: 20) {
                confirmationRow(title: "Service:", value: serviceType.rawValue)
                confirmationRow(title: "Date:", value: date.formatted(date: .long, time: .omitted))
                confirmationRow(title: "Time:", value: time.formatted(date: .omitted, time: .shortened))
                confirmationRow(title: "Duration:", value: "\(duration) hour\(duration == 1 ? "" : "s")")
                confirmationRow(title: "Location:", value: location)
                confirmationRow(title: "Total Paid:", value: String(format: "$%.2f", price))
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemBackground)))
            .padding(.horizontal)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .accessibilityIdentifier("doneBookingButton")
        }
        .padding()
        .interactiveDismissDisabled(true)
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
    }
    
    @ViewBuilder
    private func confirmationRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ProgressBarView

struct ProgressBarView: View {
    let currentStep: Int
    let steps: [String]
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<steps.count, id: \.self) { idx in
                Circle()
                    .fill(idx <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 14, height: 14)
                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(idx < currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .accentColor(.blue)
    }
}

// MARK: - NotificationHelper (unchanged)

struct NotificationHelper {
    static func requestAuthorization() {
        // Placeholder: Add UNUserNotificationCenter logic here
    }
    static func scheduleBookingConfirmedNotification(for booking: Any) {
        // Placeholder: Schedule booking notification
    }
}
