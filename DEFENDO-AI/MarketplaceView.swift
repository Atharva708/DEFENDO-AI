import Foundation
import SwiftUI
import Supabase

// BEGIN HostService MODEL
public struct HostService: Identifiable, Codable {
    public let id: String
    public let service_name: String
    public let price: Double?
    public let price_per_hour: Double?
    public let currency: String?
    public let rating: Double?
    public let city: String?
    public let service_type: String?
    public let description: String?
    public let specializations: [String]?
    public let equipment_included: [String]?
    public let images: [String]?
    public let is_active: Bool?
    public let total_bookings: Int?
    public let provider_id: String?
    public init(id: String, service_name: String, price: Double?, price_per_hour: Double?, currency: String?, rating: Double?, city: String?, service_type: String?, description: String?, specializations: [String]?, equipment_included: [String]?, images: [String]?, is_active: Bool?, total_bookings: Int?, provider_id: String?) {
        self.id = id
        self.service_name = service_name
        self.price = price
        self.price_per_hour = price_per_hour
        self.currency = currency
        self.rating = rating
        self.city = city
        self.service_type = service_type
        self.description = description
        self.specializations = specializations
        self.equipment_included = equipment_included
        self.images = images
        self.is_active = is_active
        self.total_bookings = total_bookings
        self.provider_id = provider_id
    }
}
// END HostService MODEL

// Using HostService struct defined in HostService.swift (should be in same target)

struct NewBookingFlowView: View, Identifiable {
    let id = UUID()
    let service: HostService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1

    // Step 1: Date & Time
    @State private var bookingDate = Date()
    @State private var startTime = Date()
    @State private var durationHours: Int = 1

    // Step 2: Details
    @State private var location: String = ""
    @State private var userNotes: String = ""
    @State private var paymentMethod: String = "Card"
    let paymentMethods = ["Card", "UPI", "Cash"]

    // Step 3: Status
    @State private var isSubmitting = false
    @State private var submitError: String? = nil
    @State private var submitSuccess = false
    @State private var bookingID: String? = nil

    var body: some View {
        NavigationView {
            VStack {
                if step == 1 { // Step 1: Date & Time
                    VStack(spacing: 25) {
                        Text("Step 1 of 3: Date & Time")
                            .font(.title2)
                            .fontWeight(.semibold)
                        DatePicker("Booking Date", selection: $bookingDate, displayedComponents: .date)
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        Stepper(value: $durationHours, in: 1...24) {
                            Text("Duration: \(durationHours) hour\(durationHours > 1 ? "s" : "")")
                        }
                        Button("Next") { step += 1 }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top)
                        Spacer()
                    }
                } else if step == 2 { // Step 2: Details
                    VStack(spacing: 25) {
                        Text("Step 2 of 3: Details")
                            .font(.title2)
                            .fontWeight(.semibold)
                        TextField("Location (address, venue)", text: $location)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("User Notes (optional)", text: $userNotes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Picker("Payment Method", selection: $paymentMethod) {
                            ForEach(paymentMethods, id: \.self) { method in
                                Text(method)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        HStack {
                            Button("Back") { step -= 1 }
                                .buttonStyle(PrimaryButtonStyle())
                            Button("Next") { step += 1 }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                        Spacer()
                    }
                } else if step == 3 { // Step 3: Review & Confirm
                    VStack(spacing: 20) {
                        Text("Step 3 of 3: Review & Confirm")
                            .font(.title2)
                            .fontWeight(.semibold)
                        bookingSummary
                        if let error = submitError {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                        if isSubmitting {
                            ProgressView("Submitting...")
                        } else if submitSuccess {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                Text("Booking Confirmed!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                if let bookingID = bookingID {
                                    Text("Booking ID: \(bookingID)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Button("Done") { dismiss() }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .padding(.top)
                            }
                        } else {
                            HStack {
                                Button("Back") { step -= 1 }
                                    .buttonStyle(PrimaryButtonStyle())
                                Button("Confirm Booking") { submitBooking() }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .navigationTitle("Book Service")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var bookingSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(service.service_name).font(.headline)
            if let provider = service.provider_id {
                Text("Provider ID: \(provider)").font(.caption)
            }
            Text("Date: \(bookingDate.formatted(date: .abbreviated, time: .omitted))")
            Text("Start: \(startTime.formatted(date: .omitted, time: .shortened))")
            Text("Duration: \(durationHours) hour\(durationHours > 1 ? "s" : "")")
            Text("Location: \(location)")
            if !userNotes.isEmpty {
                Text("Notes: \(userNotes)")
            }
            Text("Payment Method: \(paymentMethod)")
            if let price = service.price_per_hour ?? service.price {
                let base = Double(durationHours) * price
                let gstAmount = base * (AppConfig.Payments.gstPercent / 100.0)
                let total = base + gstAmount
                Text("Total (incl. GST): \(currencyString(total, code: service.currency ?? AppConfig.Payments.defaultCurrencyCode))")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func submitBooking() {
        isSubmitting = true
        submitError = nil
        submitSuccess = false
        let bookingIDValue = UUID().uuidString
        guard let user = authService.currentUser else {
            submitError = "User not authenticated."
            isSubmitting = false
            return
        }
        let providerID = service.provider_id ?? service.id
        let now = Date()
        let priceValue = service.price_per_hour ?? service.price ?? 0.0
        let totalPrice = Double(durationHours) * priceValue

        let endTimeValue = Calendar.current.date(byAdding: .hour, value: durationHours, to: startTime) ?? startTime

        let bookingData = BookingData(
            id: bookingIDValue,
            userId: user.id,
            providerId: providerID,
            serviceType: ServiceType.fromDb(service.service_type ?? "bodyguard"),
            date: bookingDate,
            startTime: startTime,
            endTime: endTimeValue,
            durationHours: durationHours,
            location: location,
            latitude: 0.0,
            longitude: 0.0,
            status: .pending,
            price: totalPrice,
            userNotes: userNotes.isEmpty ? nil : userNotes,
            paymentStatus: "pending",
            paymentId: nil,
            paymentGateway: nil,
            paymentMeta: nil
        )

        Task {
            do {
                let bookingIdResult = try await SupabaseService.shared.createBooking(bookingData)
                submitSuccess = true
                bookingID = bookingIdResult
            } catch {
                submitError = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}


// MARK: - MarketplaceView and related views

struct MarketplaceView: View {
    @State private var services: [HostService] = []
    @State private var isLoading = true
    @State private var fetchError: String? = nil
    @State private var selectedService: HostService? = nil
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Guards"
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(0..<6, id: \.self) { _ in ServiceSkeletonCard() }
                        }
                        .padding()
                    }
                } else if let error = fetchError {
                    ErrorStateView(
                        title: "Failed to load services",
                        message: error,
                        retryTitle: "Retry",
                        onRetry: { fetchServices() }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search providers...", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                            // Category Pills
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(categories, id: \.self) { cat in
                                        Button(action: { selectedCategory = cat }) {
                                            Text(cat)
                                                .fontWeight(.semibold)
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 16)
                                                .background(selectedCategory == cat ? Color.accentColor : Color(.secondarySystemBackground))
                                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }

                            // Results
                            LazyVStack(spacing: 20) {
                                ForEach(filteredServices) { service in
                                    VStack(spacing: 12) {
                                        ServiceCardView(service: service)
                                            .onTapGesture { selectedService = service }
                                        Button("Book Now") { selectedService = service }
                                            .buttonStyle(PrimaryButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .sheet(item: $selectedService) { svc in
                        HostServiceDetailView(service: svc)
                    }
                }
            }
            .navigationTitle("Marketplace")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {}
                }
            }
            // --- Refined SuggestBot floating button with professional theme ---
            .onAppear(perform: fetchServices)
        }
    }

    private var categories: [String] {
        ["Guards", "Drones", "Studios", "Agencies", "Escort", "Surveillance"]
    }

    private var filteredServices: [HostService] {
        services.filter { svc in
            let matchesSearch: Bool = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                svc.service_name.localizedCaseInsensitiveContains(searchText) ||
                (svc.city?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesCategory: Bool
            switch selectedCategory {
            case "Guards":
                matchesCategory = (svc.service_type ?? "").localizedCaseInsensitiveContains("guard")
            case "Drones":
                matchesCategory = (svc.service_type ?? "").localizedCaseInsensitiveContains("drone")
            case "Studios":
                matchesCategory = (svc.service_type ?? "").localizedCaseInsensitiveContains("studio")
            case "Agencies":
                matchesCategory = (svc.service_type ?? "").localizedCaseInsensitiveContains("agency")
            case "Escort":
                matchesCategory = (svc.service_type ?? "").localizedCaseInsensitiveContains("escort")
            case "Surveillance":
                matchesCategory = (svc.service_type ?? "").localizedCaseInsensitiveContains("surveillance")
            default:
                matchesCategory = true
            }
            return matchesSearch && (matchesCategory || selectedCategory.isEmpty)
        }
    }

    private func fetchServices() {
        isLoading = true
        fetchError = nil
        Task {
            do {
                // TODO: Implement fetchHostServices() in SupabaseService
                if let fetched: [HostService] = try? await SupabaseService.shared.fetchHostServices() {
                    await MainActor.run {
                        self.services = fetched
                        self.isLoading = false
                    }
                } else {
                    throw NSError(domain: "No data", code: -1, userInfo: nil)
                }
            } catch {
                await MainActor.run {
                    self.fetchError = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct ServiceCardView: View {
    let service: HostService
    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray5))
                if let imageUrl = service.images?.first, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let img):
                            img.resizable()
                               .scaledToFill()
                        case .failure(_):
                            Image(systemName: "photo").font(.title)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: "shield.lefthalf.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 84, height: 84)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(service.service_name)
                    .font(.headline)
                    .lineLimit(1)
                if let type = service.service_type {
                    Text(type.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let city = service.city {
                    Text(city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 10) {
                    if let price = service.price_per_hour ?? service.price {
                        Text(currencyString(price, code: service.currency ?? AppConfig.Payments.defaultCurrencyCode) + "/hr")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                        Text(String(format: "%.1f", service.rating ?? 0.0))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground).opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        )
    }
}

// Locale-aware currency formatting helper
private func currencyString(_ amount: Double, code: String?) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = code ?? AppConfig.Payments.defaultCurrencyCode
    return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}

struct HostServiceDetailView: View {
    let service: HostService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let imgUrl = service.images?.first, let url = URL(string: imgUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(height: 200)
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(height: 220)
                                    .clipped()
                                    .cornerRadius(24)
                                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
                            case .failure(_):
                                Image(systemName: "photo").frame(height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    Text(service.service_name)
                        .font(.largeTitle).fontWeight(.bold)
                    if let desc = service.description {
                        Text(desc).font(.body)
                    }
                    if let city = service.city {
                        Text("City: \(city)").font(.subheadline).foregroundColor(.secondary)
                    }
                    if let specializations = service.specializations, !specializations.isEmpty {
                        Text("Specializations: \(specializations.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    if let price = service.price_per_hour ?? service.price, let currency = service.currency {
                        HStack {
                            Text("Price: ")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(currency)\(String(format: "%.2f", price))/hr")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                    }
                    Button("Book This Service") {
                        showBooking = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)
                }
                .padding()
            }
            .navigationTitle("Service Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showBooking) {
                BookingFlowView(service: service)
                    .environmentObject(appState)
                    .environmentObject(authService)
            }
        }
    }
}


/// SuggestBotChatView: A simple local chat UI with hardcoded questions and answers,
/// providing a basic suggestion at the end.
//
/// *** UPDATED DESIGN & THEMING: PROFESSIONAL, BUSINESSLIKE THEME USING APP COLORS AND POLISHED UI ***
/// - Glassy blurred background with rounded corners, border, and shadow.
/// - Prominent SuggestBot avatar with accent color glow.
/// - Bot bubbles use accent color gradients, user bubbles use light surface with accent border.
/// - Typography: Questions use .headline, answers use .body; branding subtitle added.
/// - Smooth bubble transitions with combined moves and opacity.
/// - Buttons styled with PrimaryButtonStyle and accent tint.
/// - Custom close button at top-right with accent styling.
/// - Footer with subtle "DEFENDO-AI" branding text.
/// - Removed emoji mascot for sharp, clean design.
/// - Thorough inline comments for maintainability.
struct SuggestBotChatView: View {
    @Binding var isPresented: Bool

    // Questions and answer options
    private enum Question: Int, CaseIterable {
        case eventType
        case areaSize
        case securityNeed

        var text: String {
            switch self {
            case .eventType: return "What type of event are you planning?"
            case .areaSize: return "What is the approximate area size (sq ft)?"
            case .securityNeed: return "What security level do you need?"
            }
        }

        var options: [String] {
            switch self {
            case .eventType: return ["Wedding", "Concert", "Private Party", "Corporate", "Other"]
            case .areaSize: return ["< 1000", "1000 - 5000", "5000 - 10000", "> 10000"]
            case .securityNeed: return ["Low", "Medium", "High"]
            }
        }
    }

    // MARK: - State variables for question flow and answers
    @State private var currentQuestionIndex: Int = 0
    @State private var answers: [Question: String] = [:]
    @State private var showSuggestion: Bool = false

    @Namespace private var animationNamespace

    var body: some View {
        NavigationView {
            ZStack {
                // --- Glassy blurred background with rounded corners, border, and shadow ---
                Color.clear
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 20, x: 0, y: 8)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // --- SuggestBot Avatar and Title with glow ---
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
                                )
                                .frame(width: 72, height: 72)
                                .shadow(color: Color.accentColor.opacity(0.6), radius: 12, x: 0, y: 6)
                            Image(systemName: "shield.lefthalf.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggest Bot")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.6), radius: 6, x: 0, y: 1)
                            Text("Powered by DEFENDO-AI")
                                .font(.subheadline)
                                .foregroundColor(Color.accentColor.opacity(0.8))
                                .italic()
                        }
                        Spacer()
                        // --- Custom Close Button with accent styling ---
                        Button {
                            withAnimation {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.7), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Close Suggest Bot")
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    if showSuggestion {
                        // --- Suggestion View with polished style ---
                        VStack(spacing: 24) {
                            ScrollView {
                                Text(suggestionText())
                                    .multilineTextAlignment(.center)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(Color.accentColor)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.accentColor.opacity(0.12))
                                            .shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 6)
                                    )
                                    .padding(.horizontal, 24)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)).animation(.easeInOut(duration: 0.5)))
                            }
                            Spacer()
                            Button {
                                withAnimation {
                                    isPresented = false
                                }
                            } label: {
                                Text("Close")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 28)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing)
                                            )
                                            .shadow(color: Color.accentColor.opacity(0.75), radius: 10, x: 0, y: 5)
                                    )
                            }
                            .padding(.bottom, 20)
                            .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        // --- Questions & Options with stylish chat bubbles and buttons ---
                        VStack(spacing: 24) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(spacing: 20) {
                                        // Bot Question Bubble
                                        ChatBubble(text: Question.allCases[currentQuestionIndex].text,
                                                   isBot: true)
                                        .id("question\(currentQuestionIndex)")
                                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                        .animation(.easeInOut(duration: 0.4), value: currentQuestionIndex)

                                        // User Answer Bubble (if selected)
                                        if let selectedAnswer = answers[Question.allCases[currentQuestionIndex]] {
                                            ChatBubble(text: selectedAnswer,
                                                       isBot: false)
                                            .id("answer\(currentQuestionIndex)")
                                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                            .animation(.easeInOut(duration: 0.4), value: currentQuestionIndex)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    .onChange(of: currentQuestionIndex) { _ in
                                        withAnimation {
                                            proxy.scrollTo("question\(currentQuestionIndex)", anchor: .bottom)
                                        }
                                    }
                                }
                            }

                            // Options buttons styled with PrimaryButtonStyle and accent color
                            VStack(spacing: 14) {
                                ForEach(Question.allCases[currentQuestionIndex].options, id: \.self) { option in
                                    Button(action: { selectAnswer(option) }) {
                                        Text(option)
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeInOut(duration: 0.3)))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }

                    // --- Footer branding with subtle DEFENDO-AI text ---
                    Text("© DEFENDO-AI 2025")
                        .font(.footnote)
                        .foregroundColor(Color.accentColor.opacity(0.5))
                        .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }

    /// Handles answer selection, advances question or shows suggestion.
    private func selectAnswer(_ answer: String) {
        guard let question = Question(rawValue: currentQuestionIndex) else { return }
        withAnimation {
            answers[question] = answer
        }

        if currentQuestionIndex + 1 < Question.allCases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    currentQuestionIndex += 1
                }
            }
        } else {
            // All questions answered, show suggestion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation {
                    showSuggestion = true
                }
            }
        }
    }

    /// Generates suggestion text based on user's answers.
    private func suggestionText() -> String {
        // Simple hardcoded logic for suggestion based on answers
        let eventType = answers[.eventType] ?? ""
        let areaSize = answers[.areaSize] ?? ""
        let securityNeed = answers[.securityNeed] ?? ""

        var guards = 1
        var drones = 0

        switch securityNeed.lowercased() {
        case "low":
            guards = 1
            drones = 0
        case "medium":
            guards = 2
            drones = 1
        case "high":
            guards = 3
            drones = 2
        default:
            guards = 1
            drones = 0
        }

        // Adjust guards/drones by area size
        switch areaSize {
        case "< 1000":
            break
        case "1000 - 5000":
            guards += 1
        case "5000 - 10000":
            guards += 2
            drones += 1
        case "> 10000":
            guards += 3
            drones += 2
        default:
            break
        }

        return "For your \(eventType.lowercased()) event in an area of \(areaSize), " +
        "we recommend approximately \(guards) guard\(guards > 1 ? "s" : "") and \(drones) drone\(drones != 1 ? "s" : "") to ensure optimal security."
    }
}

/// Chat bubble view used for SuggestBot questions (bot) and user answers
/// *** Updated styling with businesslike theme and polished animations ***
private struct ChatBubble: View {
    let text: String
    let isBot: Bool

    var body: some View {
        HStack {
            if isBot {
                // Bot bubble aligned left with accent gradient background and glow
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 8) {
                        // Bot icon left of bubble with accent color
                        Image(systemName: "shield.lefthalf.fill")
                            .foregroundColor(Color.accentColor)
                            .font(.title3)
                            .shadow(color: Color.accentColor.opacity(0.6), radius: 4, x: 0, y: 2)
                            .padding(.bottom, 4)

                        Text(text)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                                    .clipShape(ChatBubbleShape(cornerRadius: 20, isBot: true))
                            )
                            .shadow(color: Color.accentColor.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                }
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.leading, 18)
                .padding(.trailing, 60)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                // User bubble aligned right with light surface background and accent border
                Spacer()
                Text(text)
                    .font(.body)
                    .foregroundColor(Color.primary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                            )
                    )
                    .frame(maxWidth: 320, alignment: .trailing)
                    .padding(.trailing, 18)
                    .padding(.leading, 60)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }
}

/// Custom shape for chat bubbles with tail on left (bot) or right (user)
private struct ChatBubbleShape: Shape {
    var cornerRadius: CGFloat = 16
    var isBot: Bool

    func path(in rect: CGRect) -> Path {
        let tailSize: CGFloat = 12
        var path = Path()

        if isBot {
            // Bot bubble with tail on left bottom
            path.move(to: CGPoint(x: tailSize, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY + tailSize))
            path.addLine(to: CGPoint(x: tailSize * 2, y: rect.maxY))
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY + cornerRadius),
                        tangent2End: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                        radius: cornerRadius)
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                        tangent2End: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius * 2),
                        radius: cornerRadius)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(tangent1End: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.maxX - cornerRadius * 2, y: rect.maxY),
                        radius: cornerRadius)
            path.addLine(to: CGPoint(x: tailSize * 2, y: rect.maxY))
            path.closeSubpath()
        } else {
            // User bubble with tail on right bottom
            path.move(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + tailSize))
            path.addLine(to: CGPoint(x: rect.maxX - tailSize * 2, y: rect.maxY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                        tangent2End: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY),
                        radius: cornerRadius)
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY + cornerRadius),
                        tangent2End: CGPoint(x: rect.minX, y: rect.minY + cornerRadius * 2),
                        radius: cornerRadius)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            path.addArc(tangent1End: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.minX + cornerRadius * 2, y: rect.maxY),
                        radius: cornerRadius)
            path.addLine(to: CGPoint(x: rect.maxX - tailSize * 2, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}

