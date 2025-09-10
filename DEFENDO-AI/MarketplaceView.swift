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
            serviceType: ServiceType(rawValue: service.service_type ?? "securityGuard") ?? .securityGuard,
            date: bookingDate,
            startTime: startTime,
            endTime: endTimeValue,
            durationHours: durationHours,
            location: location,
            latitude: 0.0,
            longitude: 0.0,
            status: .pending,
            price: totalPrice,
            userNotes: userNotes.isEmpty ? nil : userNotes
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

