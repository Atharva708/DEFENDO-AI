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
    public let host_id: String?
    public init(id: String, service_name: String, price: Double?, price_per_hour: Double?, currency: String?, rating: Double?, city: String?, service_type: String?, description: String?, specializations: [String]?, equipment_included: [String]?, images: [String]?, is_active: Bool?, total_bookings: Int?, host_id: String?) {
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
        self.host_id = host_id
    }
}
// END HostService MODEL

// Using HostService struct defined in HostService.swift (should be in same target)

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

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
            if let provider = service.host_id {
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
            if let price = service.price_per_hour ?? service.price, let currency = service.currency {
                let total = Double(durationHours) * price
                Text("Total: \(currency)\(String(format: "%.2f", total))")
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
        let providerID = service.host_id ?? service.id
        let now = Date()
        let priceValue = service.price_per_hour ?? service.price ?? 0.0
        let totalPrice = Double(durationHours) * priceValue

        let endTimeValue = Calendar.current.date(byAdding: .hour, value: durationHours, to: startTime) ?? startTime

        let bookingData = BookingData(
            id: bookingIDValue,
            userId: user.id,
            providerId: providerID,
            serviceType: ServiceType(rawValue: service.service_type ?? "bodyguard") ?? .bodyguard,
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
            paymentStatus: "pending"
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
                    ProgressView("Loading services...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = fetchError {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Failed to load services")
                            .font(.title3)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            fetchServices()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Text(currencyString(price, code: service.currency) + "/hr")
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
    if let code = code { f.currencyCode = code }
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

