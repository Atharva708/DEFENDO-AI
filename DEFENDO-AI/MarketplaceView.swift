import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

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
    @StateObject private var vm = ServiceDiscoveryViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search field with suggestions
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search services e.g. guards, drones", text: $vm.query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)

                    if !vm.suggestions.isEmpty && !vm.query.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.suggestions, id: \.self) { suggestion in
                                    Button(action: { vm.applySuggestion(suggestion) }) {
                                        Text(suggestion)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding([.horizontal, .top])

                if vm.isLoading && vm.cards.isEmpty {
                    ScrollView { VStack(spacing: 16) { ForEach(0..<6, id: \.self) { _ in MarketplaceSkeletonCard() } }.padding() }
                } else if let error = vm.errorMessage {
                    ErrorStateView(title: "Failed to load", message: error, retryTitle: "Retry", onRetry: { vm.retry() })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(vm.cards) { card in
                                CompanyCardViewV2(card: card)
                                    .onAppear { vm.loadMoreIfNeeded(currentId: card.id) }
                                    .onTapGesture { vm.selectedCompany = card }
                            }
                            if vm.isLoadingMore { ProgressView().padding(.vertical) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Marketplace")
            .sheet(item: $vm.selectedCompany) { company in
                HostSubservicesView(hostId: company.id, hostName: company.companyName)
                    .environmentObject(appState)
                    .environmentObject(authService)
            }
        }
        .onAppear { vm.start() }
    }
}

// MARK: - Company Card UI (glassmorphism)
struct CompanyCardViewV2: View {
    let card: SupabaseCompanyCardData
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                AsyncImage(url: URL(string: card.logoUrl ?? "")) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure(_): Image(systemName: "building.2.crop.circle").resizable().scaledToFit().foregroundColor(.accentColor)
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.companyName).font(.headline)
                    HStack(spacing: 8) {
                        if let rating = card.rating { Label(String(format: "%.1f", rating), systemImage: "star.fill").labelStyle(.titleAndIcon).foregroundColor(.yellow).font(.caption) }
                        if let city = card.city { Text(city).font(.caption).foregroundColor(.secondary) }
                    }
                }
                Spacer()
                Button("View Services") {}
                    .buttonStyle(PrimaryButtonStyle())
            }
            if !card.previewImages.isEmpty {
                HStack(spacing: 8) {
                    ForEach(card.previewImages, id: \.self) { urlStr in
                        AsyncImage(url: URL(string: urlStr)) { phase in
                            switch phase {
                            case .empty: Color.gray.opacity(0.2)
                            case .success(let img): img.resizable().scaledToFill()
                            case .failure(_): Color.gray.opacity(0.2)
                            @unknown default: Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 72, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.accentColor.opacity(0.15), radius: 12, x: 0, y: 8)
        )
    }
}

// MARK: - Subservices List
struct HostSubservicesView: View, Identifiable {
    let id = UUID()
    let hostId: String
    let hostName: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var services: [HostService] = []
    @State private var isLoading = true
    @State private var error: String? = nil

    var body: some View {
        NavigationView {
            Group {
                if isLoading { ProgressView("Loading...") }
                else if let error = error { ErrorStateView(title: "Failed to load", message: error, retryTitle: "Retry", onRetry: load) }
                else {
                    List {
                        ForEach(services) { svc in
                            HStack(alignment: .top, spacing: 12) {
                                AsyncImage(url: URL(string: svc.images?.first ?? "")) { phase in
                                    switch phase { case .empty: Color.gray.opacity(0.2); case .success(let img): img.resizable().scaledToFill(); case .failure(_): Color.gray.opacity(0.2); @unknown default: Color.gray.opacity(0.2) }
                                }
                                .frame(width: 76, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(svc.service_name).font(.headline)
                                    if let desc = svc.description { Text(desc).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                                    if let rating = svc.rating { HStack(spacing: 4) { Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption2); Text(String(format: "%.1f", rating)).font(.caption2).foregroundColor(.secondary) } }
                                }
                                Spacer()
                                Button("Book Now") { presentBooking(for: svc) }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                            .listRowBackground(Color.clear.background(.ultraThinMaterial))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(hostName)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear(perform: load)
        }
    }

    private func load() {
        isLoading = true; error = nil
        Task {
            do {
                let result = try await SupabaseService.shared.fetchSubcategoryServices(for: hostId)
                await MainActor.run { self.services = result; self.isLoading = false }
            } catch { await MainActor.run { self.error = error.localizedDescription; self.isLoading = false } }
        }
    }

    private func presentBooking(for service: HostService) {
        // Present the booking flow in a sheet using SwiftUI
        // Fallback to opening a simple booking flow inline if HostServiceDetailView is unavailable
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let hosting = UIHostingController(rootView: NewBookingFlowView(service: service).environmentObject(appState).environmentObject(authService))
        hosting.modalPresentationStyle = .formSheet
        windowScene?.keyWindow?.rootViewController?.present(hosting, animated: true)
    }
}

// MARK: - ViewModel
final class ServiceDiscoveryViewModel: ObservableObject, Identifiable {
    @Published var query: String = "" { didSet { scheduleSearch() } }
    @Published var cards: [SupabaseCompanyCardData] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedCompany: SupabaseCompanyCardData? = nil
    @Published var suggestions: [String] = []

    private var offset: Int = 0
    private let pageSize: Int = 12
    private var hasMore: Bool = true
    private var debounceTask: Task<Void, Never>? = nil

    func start() { loadRecentSuggestions(); performSearch(reset: true) }
    func retry() { performSearch(reset: true) }
    func applySuggestion(_ text: String) { query = text }

    func loadMoreIfNeeded(currentId: String) {
        guard hasMore, !isLoadingMore, let last = cards.last, last.id == currentId else { return }
        isLoadingMore = true
        Task { await fetchPage() }
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run { self?.performSearch(reset: true) }
        }
        saveRecentQuery(query)
        updateSuggestions(for: query)
    }

    private func performSearch(reset: Bool) {
        if reset { offset = 0; hasMore = true; cards.removeAll() }
        isLoading = reset
        errorMessage = nil
        Task { await fetchPage() }
    }

    @MainActor
    private func fetchPage() async {
        do {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let data = try await SupabaseService.shared.searchCompanies(offering: q.isEmpty ? "guard" : q, limit: pageSize, offset: offset)
            if data.count < pageSize { hasMore = false }
            offset += data.count
            cards.append(contentsOf: data)
            isLoading = false; isLoadingMore = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false; isLoadingMore = false
        }
    }

    // MARK: - Suggestions caching
    private let recentKey = "recent_service_queries"
    private func loadRecentSuggestions() { suggestions = (UserDefaults.standard.array(forKey: recentKey) as? [String]) ?? [] }
    private func saveRecentQuery(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var recents = (UserDefaults.standard.array(forKey: recentKey) as? [String]) ?? []
        recents.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recents.insert(trimmed, at: 0)
        if recents.count > 8 { recents = Array(recents.prefix(8)) }
        UserDefaults.standard.set(recents, forKey: recentKey)
        suggestions = recents
    }
    private func updateSuggestions(for q: String) {
        let recents = (UserDefaults.standard.array(forKey: recentKey) as? [String]) ?? []
        guard !q.isEmpty else { suggestions = recents; return }
        suggestions = recents.filter { $0.localizedCaseInsensitiveContains(q) }
    }
}

// A minimal stand-in for SupabaseService.CompanyCardData to resolve type references if the SDK differs.
// Replace this with the actual type from SupabaseService if available in your project.
struct SupabaseCompanyCardData: Identifiable, Hashable {
    let id: String
    let companyName: String
    let logoUrl: String?
    let rating: Double?
    let city: String?
    let previewImages: [String]
}

// Skeleton used while loading
private struct MarketplaceSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5)).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5)).frame(width: 160, height: 14)
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5)).frame(width: 100, height: 10)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5)).frame(width: 72, height: 48)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground))
        )
        .redacted(reason: .placeholder)
    }
}

/// SuggestBotChatView and helpers retained as-is from the user's file
struct SuggestBotChatView: View {
    @Binding var isPresented: Bool

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

    @State private var currentQuestionIndex: Int = 0
    @State private var answers: [Question: String] = [:]
    @State private var showSuggestion: Bool = false

    @Namespace private var animationNamespace

    var body: some View {
        NavigationView {
            ZStack {
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
                        Button {
                            withAnimation { isPresented = false }
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
                            }
                            Spacer()
                            Button { withAnimation { isPresented = false } } label: {
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        VStack(spacing: 24) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(spacing: 20) {
                                        ChatBubble(text: Question.allCases[currentQuestionIndex].text, isBot: true)
                                            .id("question\(currentQuestionIndex)")
                                        if let selectedAnswer = answers[Question.allCases[currentQuestionIndex]] {
                                            ChatBubble(text: selectedAnswer, isBot: false)
                                                .id("answer\(currentQuestionIndex)")
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    .onChange(of: currentQuestionIndex) { _ in
                                        withAnimation { proxy.scrollTo("question\(currentQuestionIndex)", anchor: .bottom) }
                                    }
                                }
                            }

                            VStack(spacing: 14) {
                                ForEach(Question.allCases[currentQuestionIndex].options, id: \.self) { option in
                                    Button(action: { selectAnswer(option) }) {
                                        Text(option)
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }

                    Text("© DEFENDO-AI 2025")
                        .font(.footnote)
                        .foregroundColor(Color.accentColor.opacity(0.5))
                        .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func selectAnswer(_ answer: String) {
        guard let question = Question(rawValue: currentQuestionIndex) else { return }
        withAnimation { answers[question] = answer }
        if currentQuestionIndex + 1 < Question.allCases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { currentQuestionIndex += 1 } }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { showSuggestion = true } }
        }
    }

    private func suggestionText() -> String {
        let eventType = answers[.eventType] ?? ""
        let areaSize = answers[.areaSize] ?? ""
        let securityNeed = answers[.securityNeed] ?? ""
        var guards = 1
        var drones = 0
        switch securityNeed.lowercased() {
        case "low": guards = 1; drones = 0
        case "medium": guards = 2; drones = 1
        case "high": guards = 3; drones = 2
        default: guards = 1; drones = 0
        }
        switch areaSize {
        case "< 1000": break
        case "1000 - 5000": guards += 1
        case "5000 - 10000": guards += 2; drones += 1
        case "> 10000": guards += 3; drones += 2
        default: break
        }
        return "For your \(eventType.lowercased()) event in an area of \(areaSize), we recommend approximately \(guards) guard\(guards > 1 ? "s" : "") and \(drones) drone\(drones != 1 ? "s" : "") to ensure optimal security."
    }
}

private struct ChatBubble: View {
    let text: String
    let isBot: Bool

    var body: some View {
        HStack {
            if isBot {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 8) {
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
            } else {
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
            }
        }
    }
}

private struct ChatBubbleShape: Shape {
    var cornerRadius: CGFloat = 16
    var isBot: Bool

    func path(in rect: CGRect) -> Path {
        let tailSize: CGFloat = 12
        var path = Path()
        if isBot {
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

// Locale-aware currency formatting helper
private func currencyString(_ amount: Double, code: String?) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = code ?? AppConfig.Payments.defaultCurrencyCode
    return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}
