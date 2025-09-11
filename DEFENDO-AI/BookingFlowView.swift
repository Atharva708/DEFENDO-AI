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
    
    // Optional HostService passed for bookings coming from a host's listing
    let service: HostService?
    
    @State private var currentStep = 0
    
    // Step 1
    // If service provided, use its default serviceType, else default to securityGuard
    @State private var selectedService: ServiceType
    
    // Step 2
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    
    // Step 3
    @State private var selectedDuration = 4
    @State private var location = ""
    @State private var specialInstructions = ""
    
    // Step 4
    @State private var selectedPaymentMethod: PaymentMethod = .upi
    
    // Payment & UI State
    @State private var isProcessingPayment = false
    @State private var paymentErrorMessage: String? = nil
    @State private var showPaymentError = false
    @State private var showBookingConfirmation = false
    @State private var preSavedBookingId: String? = nil
    
    // Show previous bookings sheet
    @State private var showPreviousBookings = false
    
    // Razorpay
    @State private var razorpay: RazorpayCheckout?
    @State private var razorpayCoordinator: RazorpayCheckoutCoordinator?
    
    let steps = ["Select Service", "Date & Time", "Duration & Location", "Confirm & Pay"]
    
    init(service: HostService? = nil) {
        self.service = service
        // Initialize selectedService from service if available, else default
        if let svc = service {
            _selectedService = State(initialValue: ServiceType(rawValue: svc.service_type ?? "") ?? .securityGuard)
        } else {
            _selectedService = State(initialValue: .securityGuard)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    // Show custom header if service is provided, else show progress bar and generic title
                    if let hostService = service {
                        // Custom header with image and name, price if available
                        VStack(spacing: 8) {
                            if let imageUrlString = hostService.images?.first, let url = URL(string: imageUrlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 140, height: 140)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .shadow(radius: 5)
                                    case .failure(_):
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 140, height: 140)
                                            .foregroundColor(.gray)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "shield.lefthalf.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 140, height: 140)
                                    .foregroundColor(.gray)
                            }
                            
                            Text(hostService.service_name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                            
                            if let pricePerHour = hostService.price_per_hour {
                                Text(formatCurrency(pricePerHour, code: hostService.currency))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top)
                        .padding(.bottom, 10)
                    } else {
                        // Show progress bar with generic "Book Service" title
                        ProgressBarView(currentStep: currentStep, steps: steps)
                            .padding(.top)
                            .padding(.horizontal)
                            .accentColor(.blue)
                    }
                    
                    Group {
                        switch currentStep {
                        case 0:
                            // If HostService is provided, skip service selection step and show a summary instead
                            if service != nil {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Service Selected")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }
                                    Text(service?.service_name ?? selectedService.rawValue)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    if let pricePerHour = service?.price_per_hour {
                                        Text(String(format: "$%.2f / hr", pricePerHour))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .shadow(radius: 7, y: 2)
                                )
                                .padding(.horizontal)
                            } else {
                                // Normal service selection step
                                ServiceSelectionStep(selectedService: $selectedService)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .shadow(radius: 7, y: 2)
                                    )
                                    .padding(.horizontal)
                            }
                        case 1:
                            DateTimeSelectionStep(
                                selectedDate: $selectedDate,
                                selectedTime: $selectedTime,
                                showValidationError: !canProceedToNextStep(),
                                onDateOrTimeChanged: { /* trigger UI update if needed */ },
                                onBack: {
                                    withAnimation { currentStep -= 1 }
                                    triggerHapticImpact()
                                },
                                onNext: {
                                    withAnimation { currentStep += 1 }
                                    triggerHapticImpact()
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
                                totalPrice: calculateTotalPrice(),
                                hostService: service // Pass host service for more detail in confirmation
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
                    // Ensure a visible Next button at Step 0 when a host service is preselected.
                    // Avoid duplicating controls on Step 1 (Date & Time) because that step has its own toolbar.
                    if (currentStep != 1) && ( (service == nil && (currentStep == 0 || currentStep >= 2)) ||
                        (service != nil && currentStep >= 0) ) {
                        HStack {
                            if currentStep == 1 && service == nil {
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
                                    triggerHapticImpact()
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
            .navigationTitle(service != nil ? service?.service_name ?? "Book Service" : "Book Service")
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
            /*
            Removed fullScreenCover for booking confirmation,
            as now we auto-navigate to Booking screen upon successful payment.
             
            .fullScreenCover(isPresented: $showBookingConfirmation, onDismiss: {
                appState.currentScreen = .dashboard
            }) {
                BookingConfirmationView(
                    serviceType: selectedService,
                    date: selectedDate,
                    time: selectedTime,
                    duration: selectedDuration,
                    location: location,
                    price: calculateTotalPrice(),
                    hostService: service // Pass host service for confirmation view
                )
            }
            */
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
            // If host service is provided, step 0 is skipped, so always true here
            if service != nil {
                return true
            }
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
        // Pre-save a pending booking before starting payment (best-effort)
        Task { _ = await ensurePreSavedBooking() }
        
        let amountInPaise = Int(calculateSubtotal() * 100) // Razorpay amount in paise (INR, without GST)
        
        // Razorpay Key ID (test)
        let razorpayKey = "rzp_test_RDymBSsTitkLdn"
        
        // TODO: The Razorpay Key Secret must be used on your backend to create and sign Razorpay orders securely.
        // Do NOT embed or use the Key Secret in this iOS app, to keep your integration secure.
        
        // Initialize coordinator with success and failure handlers
        let coordinator = RazorpayCheckoutCoordinator(
            onSuccess: { paymentId, paymentMeta in
                handleRazorpayPaymentSuccess(paymentId: paymentId, paymentMeta: paymentMeta)
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
            ],
            "notes": [
                "qr_code_id": "qr_REBKIrPN7MM76x"
            ]
            // TODO: Add more options if needed (e.g., order_id, notes, address etc.)
        ]
        
        // Find top-most view controller to present Razorpay
        let rootVC: UIViewController? = (
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        )
        if let presenter = topViewController(from: rootVC) {
            razorpayInstance.open(options, displayController: presenter)
        } else {
            isProcessingPayment = false
            paymentErrorMessage = "Unable to present payment gateway."
            showPaymentError = true
        }
    }

    // Resolve the top-most view controller for presentation
    private func topViewController(from root: UIViewController?) -> UIViewController? {
        guard let root = root else { return nil }
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
    
    private func handleRazorpayPaymentSuccess(paymentId: String?, paymentMeta: [AnyHashable: Any]?) {
        Task {
            await markBookingPaidIfNeeded()
            await saveBookingAfterPurchase(paymentId: paymentId, paymentMeta: paymentMeta)
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
    private func saveBookingAfterPurchase(paymentId: String?, paymentMeta: [AnyHashable: Any]?) async {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year,.month,.day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour,.minute], from: selectedTime)
        startComponents.hour = timeComponents.hour
        startComponents.minute = timeComponents.minute
        let startTime = calendar.date(from: startComponents) ?? selectedDate
        let endTime = calendar.date(byAdding: .hour, value: selectedDuration, to: startTime) ?? startTime
        
        // Use the real user id or fallback mock
        let userId = authService.currentUser?.id ?? "mock-user-id"
        
        // If host service is provided, use its id for providerId and service_type, else fallback to demo values
        let providerId: String
        let serviceTypeRaw: String
        let priceToUse: Double
        
        if let hostService = service {
            providerId = hostService.id
            serviceTypeRaw = hostService.service_type ?? selectedService.rawValue
            priceToUse = hostService.price_per_hour ?? calculateTotalPrice() / Double(selectedDuration)
        } else {
            providerId = "provider-id-1"
            serviceTypeRaw = selectedService.rawValue
            priceToUse = calculateTotalPrice() / Double(selectedDuration)
        }
        
        // Save payment details to bookings table for transaction tracking.
        let paymentIdString = paymentId ?? ""
        let paymentMetaString: String
        if let meta = paymentMeta {
            if let data = try? JSONSerialization.data(withJSONObject: meta, options: []),
               let jsonString = String(data: data, encoding: .utf8) {
                paymentMetaString = jsonString
            } else {
                paymentMetaString = "\(meta)"
            }
        } else {
            paymentMetaString = ""
        }
        
        // Create booking payload (used for local confirmation display or fallback create)
        let bookingData = BookingData(
            id: UUID().uuidString,
            userId: userId,
            providerId: providerId,
            serviceType: ServiceType(rawValue: serviceTypeRaw) ?? selectedService,
            date: selectedDate,
            startTime: startTime,
            endTime: endTime,
            durationHours: selectedDuration,
            location: location,
            latitude: nil as Double?,
            longitude: nil as Double?,
            status: .pending,
            price: priceToUse * Double(selectedDuration),
            userNotes: specialInstructions,
            paymentStatus: selectedPaymentMethod == .upi ? "paid_upi" : "paid",
            paymentId: paymentIdString,
            paymentGateway: "Razorpay",
            paymentMeta: paymentMetaString
        )

        // If we pre-saved, don't create a duplicate; just show confirmation
        let saved: Bool
        if preSavedBookingId != nil {
            saved = true
        } else {
            saved = await saveBookingToSupabase(bookingData: bookingData)
        }
        isProcessingPayment = false
        if saved {
            NotificationHelper.scheduleBookingConfirmedNotification(for: bookingData)
            // Instead of showing confirmation sheet, automatically switch to Booking tab
            appState.currentScreen = .booking
            triggerHapticSuccess()
        } else {
            paymentErrorMessage = "Failed to save your booking. Please try again."
            showPaymentError = true
            triggerHapticError()
        }
    }
    
    // Calculate total price using host service price if available, else fallback
    private func calculateTotalPrice() -> Double {
        if let hostService = service, let pricePerHour = hostService.price_per_hour {
            return pricePerHour * Double(selectedDuration)
        } else {
            let hourlyRate = selectedService == .securityGuard ? 25.0 : 35.0
            return hourlyRate * Double(selectedDuration)
        }
    }
    
    private func calculateSubtotal() -> Double {
        if let hostService = service, let pricePerHour = hostService.price_per_hour {
            return pricePerHour * Double(selectedDuration)
        } else {
            let hourlyRate = selectedService == .securityGuard ? 25.0 : 35.0
            return hourlyRate * Double(selectedDuration)
        }
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

    // MARK: - Pre-save and status update
    private func ensurePreSavedBooking() async -> String? {
        if let id = preSavedBookingId { return id }
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year,.month,.day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour,.minute], from: selectedTime)
        startComponents.hour = timeComponents.hour
        startComponents.minute = timeComponents.minute
        let startTime = calendar.date(from: startComponents) ?? selectedDate
        let endTime = calendar.date(byAdding: .hour, value: selectedDuration, to: startTime) ?? startTime
        let userId = authService.currentUser?.id ?? "mock-user-id"
        let providerId = service?.id ?? "provider-id-1"
        let pricePerHour = service?.price_per_hour ?? calculateTotalPrice() / Double(selectedDuration)
        let pendingBooking = BookingData(
            id: UUID().uuidString,
            userId: userId,
            providerId: providerId,
            serviceType: service != nil ? (ServiceType(rawValue: service?.service_type ?? selectedService.rawValue) ?? selectedService) : selectedService,
            date: selectedDate,
            startTime: startTime,
            endTime: endTime,
            durationHours: selectedDuration,
            location: location,
            latitude: nil as Double?,
            longitude: nil as Double?,
            status: .pending,
            price: pricePerHour * Double(selectedDuration),
            userNotes: specialInstructions,
            paymentStatus: "initiated",
            paymentId: nil,
            paymentGateway: nil,
            paymentMeta: nil
        )
        do {
            let id = try await SupabaseService.shared.createBooking(pendingBooking)
            preSavedBookingId = id
            return id
        } catch {
            print("Pre-save booking failed: \(error)")
            return nil
        }
    }

    private func markBookingPaidIfNeeded() async {
        guard let id = preSavedBookingId else { return }
        do {
            try await SupabaseService.shared.updateBookingStatusAndPayment(id: id, status: .confirmed, paymentStatus: "paid")
        } catch {
            print("Failed to update booking payment status: \(error)")
        }
    }

    // MARK: - Haptics
    private func triggerHapticImpact() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    private func triggerHapticSuccess() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    private func triggerHapticError() { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    // MARK: - Currency Formatting
    private func formatCurrency(_ amount: Double, code: String?) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        if let code = code { f.currencyCode = code }
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

// MARK: - RazorpayCheckoutCoordinator

class RazorpayCheckoutCoordinator: NSObject, RazorpayPaymentCompletionProtocolWithData {
    let onSuccess: (_ paymentId: String?, _ paymentMeta: [AnyHashable: Any]?) -> Void
    let onFailure: (String) -> Void
    init(onSuccess: @escaping (_ paymentId: String?, _ paymentMeta: [AnyHashable: Any]?) -> Void, onFailure: @escaping (String) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    func onPaymentSuccess(_ payment_id: String?, andData response: [AnyHashable : Any]?) {
        onSuccess(payment_id, response)
    }
    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable : Any]?) {
        onFailure(str)
    }
}

// MARK: - PaymentMethod Enum

enum PaymentMethod: String, CaseIterable, Identifiable {
    case upi = "UPI"
    case card = "Card"
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
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
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accessibilityIdentifier("compactTimePicker")
                        .onChange(of: selectedTime) { _ in
                            hasInteracted = true
                            onDateOrTimeChanged?()
                        }
                    
                    HStack(spacing: 10) {
                        ForEach([30, 60, 120], id: \.self) { minutes in
                            Button("+\(minutes == 60 ? "1h" : minutes == 120 ? "2h" : "30m")") {
                                let newDate = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
                                selectedDate = newDate
                                selectedTime = newDate
                                onDateOrTimeChanged?()
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            if showValidationError && hasInteracted {
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
                }
                .padding(.vertical)
            }
            
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
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .padding(.vertical)
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
    
    let hostService: HostService? // Optional host service to show additional details
    
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
                    // Show service info from hostService if available, otherwise fallback
                    if let hostService = hostService {
                        infoRow(iconName: "shield.lefthalf.fill", iconColor: .blue, title: "Service", subtitle: hostService.service_name)
                        
                        if !(hostService.specializations ?? []).isEmpty {
                            infoRow(iconName: "star.fill", iconColor: .yellow, title: "Specializations", subtitle: (hostService.specializations ?? []).joined(separator: ", "))
                        }
                        
                        if !(hostService.city ?? "").isEmpty {
                            infoRow(iconName: "building.2.fill", iconColor: .secondary, title: "City", subtitle: hostService.city ?? "")
                        }
                    } else {
                        infoRow(iconName: "shield.lefthalf.fill", iconColor: .blue, title: "Service", subtitle: selectedService.rawValue)
                    }
                    
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
                
                // Price Breakdown with GST/tax (INR)
                PriceBreakdownView(
                    hourlyRate: hostService?.price_per_hour ?? (selectedService == .securityGuard ? 25.0 : 35.0),
                    durationHours: selectedDuration,
                    currencyCode: hostService?.currency ?? "INR"
                )
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

// MARK: - Price Breakdown View (GST/tax for INR)
struct PriceBreakdownView: View {
    let hourlyRate: Double
    let durationHours: Int
    let currencyCode: String
    // Example GST 18% (CGST 9% + SGST 9%) only when INR
    private var gstRate: Double { currencyCode.uppercased() == "INR" ? 0.18 : 0.0 }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Hourly Rate:")
                Spacer()
                Text(currencyString(hourlyRate, code: currencyCode))
            }
            HStack {
                Text("Duration:")
                Spacer()
                Text("\(durationHours) hour\(durationHours == 1 ? "" : "s")")
            }
            Divider()
            HStack {
                Text("Subtotal:")
                Spacer()
                Text(currencyString(subtotal, code: currencyCode))
            }
            if gstRate > 0 {
                HStack {
                    Text("GST (18%):")
                    Spacer()
                    Text(currencyString(tax, code: currencyCode))
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Divider()
            HStack {
                Text("Total Payable:")
                    .font(.headline)
                Spacer()
                Text(currencyString(total, code: currencyCode))
                    .font(.headline)
            }
        }
    }
    
    private var subtotal: Double { hourlyRate * Double(durationHours) }
    private var tax: Double { subtotal * gstRate }
    private var total: Double { subtotal + tax }
    
    private func currencyString(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
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
    
    let hostService: HostService? // Optional host service for extended info
    
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
                if let hostService = hostService {
                    confirmationRow(title: "Service:", value: hostService.service_name)
                    
                    if !(hostService.specializations ?? []).isEmpty {
                        confirmationRow(title: "Specializations:", value: (hostService.specializations ?? []).joined(separator: ", "))
                    }
                    
                    if !(hostService.city ?? "").isEmpty {
                        confirmationRow(title: "City:", value: hostService.city ?? "")
                    }
                } else {
                    confirmationRow(title: "Service:", value: serviceType.rawValue)
                }
                
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

