//
// BookingFlowView.swift
// DEFENDO-AI
//

import SwiftUI
import UserNotifications
import Supabase

struct BookingFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    
    // Optional HostService passed for bookings coming from a host's listing
    let service: HostService?
    @State private var currentStep = 0
    
    // Step 1
    // If service provided, use its default serviceType, else default to bodyguard
    @State private var selectedService: ServiceType
    
    // Step 2
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    
    // Step 3
    @State private var selectedDuration = 4
    @State private var location = ""
    @State private var specialInstructions = ""
    
    // Booking & UI State
    @State private var showBookingConfirmation = false
    @State private var lastPaymentId: String? = nil
    @State private var lastBookingId: String? = nil
    
    // Show previous bookings sheet
    @State private var showPreviousBookings = false
    
    let steps = ["Select Service", "Date & Time", "Duration & Location", "Review & Confirm"]
    
    init(service: HostService? = nil) {
        self.service = service
        // Initialize selectedService from service if available, else default to bodyguard
        if let svc = service {
            _selectedService = State(initialValue: ServiceType.fromDb(svc.service_type ?? "bodyguard"))
        } else {
            _selectedService = State(initialValue: .bodyguard)
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
                                Text(formatCurrency(pricePerHour, code: service?.currency ?? AppConfig.Payments.defaultCurrencyCode) + " / hr")
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
                            ReviewConfirmStep(
                                selectedService: selectedService,
                                selectedDate: selectedDate,
                                selectedTime: selectedTime,
                                selectedDuration: selectedDuration,
                                location: location,
                                specialInstructions: specialInstructions,
                                hostService: service,
                                onConfirm: { saveBooking() }
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
                    
                    // Bottom bar:
                    // Step 1 has its own toolbar, so skip bottom bar on step 1
                    HStack {
                        if currentStep > 0 {
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
                        // Confirm and handle payment before saving booking
                                saveBooking()
                            }
                        }) {
                            Text(currentStep == 3 ? "Confirm Booking" : "Next")
                                .bold()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canProceedToNextStep())
                        .accessibilityIdentifier("nextOrConfirmButton")
                    }
                    .padding()
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
            .sheet(isPresented: $showPreviousBookings) {
                PreviousBookingsView()
                    .environmentObject(authService)
            }
            .onAppear {
                NotificationHelper.requestAuthorization()
                #if !targetEnvironment(macCatalyst)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
            .sheet(isPresented: $showBookingConfirmation) {
                BookingConfirmationView(
                    serviceType: selectedService,
                    date: selectedDate,
                    time: selectedTime,
                    duration: selectedDuration,
                    location: location,
                    price: calculateTotalPrice(),
                    transactionId: lastPaymentId,
                    bookingId: lastBookingId,
                    hostService: service
                )
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
    
    // MARK: - Booking Save
    
    private func saveBooking() {
        Task { await saveBookingAsync() }
    }
    
    @MainActor
    private func saveBookingAsync() async {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year,.month,.day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour,.minute], from: selectedTime)
        startComponents.hour = timeComponents.hour
        startComponents.minute = timeComponents.minute
        let startTime = calendar.date(from: startComponents) ?? selectedDate
        let endTime = calendar.date(byAdding: .hour, value: selectedDuration, to: startTime) ?? startTime
        
        // Require authenticated user
        guard let userId = authService.currentUser?.id else {
            // Show error alert (using alert here instead of paymentError)
            // Could be enhanced with a state for an alert if needed
            return
        }
        
        // If host service is provided, resolve provider id; otherwise fail
        let provider_id: String
        if let hostService = service {
            provider_id = hostService.provider_id ?? hostService.id
        } else {
            // Show error alert or message
            return
        }
        
        let priceToUse: Double
        
        if let hostService = service {
            priceToUse = hostService.price_per_hour ?? calculateTotalPrice() / Double(selectedDuration)
        } else {
            priceToUse = calculateTotalPrice() / Double(selectedDuration)
        }
        
        let bookingData = BookingData(
            id: UUID().uuidString,
            userId: userId,
            providerId: provider_id,
            serviceType: selectedService, // Use selectedService instead of .securityGuard
            date: selectedDate,
            startTime: startTime,
            endTime: endTime,
            durationHours: selectedDuration,
            location: location,
            latitude: nil as Double?,
            longitude: nil as Double?,
            status: .pending,
            price: applyGst(priceToUse * Double(selectedDuration)),
            userNotes: specialInstructions,
            paymentStatus: "pending",
            paymentId: nil,
            paymentGateway: nil,
            paymentMeta: nil
        )
        
        // 1) Process payment first
        let currencyCode = service?.currency ?? AppConfig.Payments.defaultCurrencyCode
        let totalAmount = bookingData.price
        let paymentRequest = RazorpayService.PaymentRequest(
            amount: totalAmount,
            currencyCode: currencyCode,
            description: "Booking payment for \(selectedService.dbValue)",
            orderId: nil,
            metadata: ["provider_id": provider_id],
            customerEmail: authService.currentUser?.email,
            customerPhone: authService.currentUser?.phone
        )

        do {
            let result = try await RazorpayService.shared.pay(paymentRequest)
            print("Razorpay payment success:", result)

            // 2) Only after success, save booking with paid status
            let paidBooking = BookingData(
                id: bookingData.id,
                userId: bookingData.userId,
                providerId: bookingData.providerId,
                serviceType: bookingData.serviceType,
                date: bookingData.date,
                startTime: bookingData.startTime,
                endTime: bookingData.endTime,
                durationHours: bookingData.durationHours,
                location: bookingData.location,
                latitude: bookingData.latitude,
                longitude: bookingData.longitude,
                status: .confirmed,
                price: bookingData.price,
                userNotes: bookingData.userNotes,
                paymentStatus: "paid",
                paymentId: result.paymentId,
                paymentGateway: "Razorpay",
                paymentMeta: result.status
            )

            let saved = await saveBookingToSupabase(bookingData: paidBooking)
            if saved {
                NotificationHelper.schedule(title: "Booking Confirmed", body: "Your booking for \(serviceDisplayName(paidBooking.serviceType)) is confirmed.")
                // Populate IDs
                lastPaymentId = result.paymentId
                lastBookingId = paidBooking.id
                triggerHapticSuccess()
                // Redirect to bookings page
                await MainActor.run { appState.currentScreen = .booking }
                // Fire background status notifications
                Task { await simulateLiveStatusNotifications(for: paidBooking) }
            } else {
                triggerHapticError()
            }
        } catch {
            print("Payment failed: \(error.localizedDescription)")
            triggerHapticError()
        }
    }

    // User-friendly service display name
    private func serviceDisplayName(_ type: ServiceType) -> String {
        type.dbValue.replacingOccurrences(of: "_", with: " ")
    }

    // Lightweight simulated tracking like Swiggy. Replace with realtime updates when backend is ready.
    private func simulateLiveStatusNotifications(for booking: BookingData) async {
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            NotificationHelper.schedule(title: "Assigning Provider", body: "We're assigning the best professional for you…")
            try await Task.sleep(nanoseconds: 6_000_000_000)
            NotificationHelper.schedule(title: "Provider En Route", body: "Your provider is on the way to \(booking.location).")
            try await Task.sleep(nanoseconds: 10_000_000_000)
            NotificationHelper.schedule(title: "Service Started", body: "Your booked service has started.")
        } catch {
            // Ignore cancellation
        }
    }
    
    private func calculateTotalPrice() -> Double {
        if let hostService = service, let pricePerHour = hostService.price_per_hour {
            return applyGst(pricePerHour * Double(selectedDuration))
        } else {
            let hourlyRate = selectedService == .bodyguard ? 25.0 : 35.0
            return applyGst(hourlyRate * Double(selectedDuration))
        }
    }

    private func applyGst(_ base: Double) -> Double {
        let gst = AppConfig.Payments.gstPercent / 100.0
        let value = base * (1.0 + gst)
        let factor = pow(10.0, 2.0)
        return (value * factor).rounded() / factor
    }
    
    // Modified to accept BookingData for Supabase saving
    private func saveBookingToSupabase(bookingData: BookingData) async -> Bool {
        print("Attempting to save booking:", bookingData)
        do {
            try await SupabaseService.shared.createBooking(bookingData)
            return true
        } catch {
            print("Supabase error: \(error)")
            if let supaError = error as? NSError {
                print("Supabase error domain: \(supaError.domain), code: \(supaError.code), userInfo: \(supaError.userInfo)")
            }
            if let localized = (error as? LocalizedError)?.errorDescription {
                print("Supabase error (localized): \(localized)")
            }
            return false
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
        f.currencyCode = code ?? AppConfig.Payments.defaultCurrencyCode
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

// MARK: - Review & Confirm Step (replaces ConfirmPaymentStep)

struct ReviewConfirmStep: View {
    let selectedService: ServiceType
    let selectedDate: Date
    let selectedTime: Date
    let selectedDuration: Int
    let location: String
    let specialInstructions: String
    
    let hostService: HostService? // Optional host service to show additional details
    
    let onConfirm: () -> Void
    
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

// MARK: - PaymentMethod Enum Removed

// MARK: - BookingConfirmationView (unchanged, used for final confirmation)

struct BookingConfirmationView: View {
    let serviceType: ServiceType
    let date: Date
    let time: Date
    let duration: Int
    let location: String
    let price: Double
    var transactionId: String? = nil
    var bookingId: String? = nil
    
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
                confirmationRow(title: "Total Paid:", value: String(format: "₹%.2f", price))
                if let tid = transactionId {
                    confirmationRow(title: "Transaction ID:", value: tid)
                }
                if let bid = bookingId {
                    confirmationRow(title: "Booking ID:", value: bid)
                }
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

// MARK: - ProgressBarView (unchanged)

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
    static func schedule(title: String, body: String) {
        // Minimal local notification helper
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}

