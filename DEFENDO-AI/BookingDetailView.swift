import SwiftUI
import MapKit

struct BookingDetailView: View, Identifiable {
    let id = UUID()
    let booking: BookingData
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var showCancelAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    statusSection
                    infoGrid
                    if let lat = booking.latitude, let lon = booking.longitude {
                        mapSection(lat: lat, lon: lon)
                    }
                    actions
                }
                .padding()
            }
            .navigationTitle("Booking Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: iconForService(booking.serviceType))
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 6) {
                    Text(serviceDisplayName(booking.serviceType).capitalized)
                        .font(.title2).bold()
                    Text(booking.providerId)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                StatusBadge(status: booking.status)
                PaymentBadge(status: booking.paymentStatus)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.headline)
            ProgressView(value: progressForStatus(booking.status)) {
                Text(progressTitle(for: booking.status))
            } currentValueLabel: {
                Text(String(format: "%.0f%%", progressForStatus(booking.status) * 100))
                    .font(.caption).foregroundColor(.secondary)
            }
            .tint(colorForStatus(booking.status))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
    }
    
    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    labelCell("Date"); valueCell(formatDate(booking.date))
                }
                GridRow {
                    labelCell("Time"); valueCell(formatTime(booking.startTime) + " - " + formatTime(booking.endTime))
                }
                GridRow {
                    labelCell("Duration"); valueCell("\(booking.durationHours) hour\(booking.durationHours == 1 ? "" : "s")")
                }
                GridRow {
                    labelCell("Location"); valueCell(booking.location)
                }
                GridRow {
                    labelCell("Service Type"); valueCell(serviceDisplayName(booking.serviceType))
                }
                GridRow {
                    labelCell("Provider ID"); valueCell(booking.providerId)
                }
                GridRow {
                    labelCell("Price (incl. GST)"); valueCell(currencyString(booking.price, code: AppConfig.Payments.defaultCurrencyCode))
                }
                GridRow {
                    labelCell("Payment"); valueCell(booking.paymentStatus.capitalized)
                }
                if let pid = booking.paymentId, !pid.isEmpty {
                    GridRow {
                        labelCell("Payment ID"); valueCell(pid)
                    }
                }
                if let gw = booking.paymentGateway, !gw.isEmpty {
                    GridRow {
                        labelCell("Gateway"); valueCell(gw)
                    }
                }
                if let meta = booking.paymentMeta, !meta.isEmpty {
                    GridRow {
                        labelCell("Payment Meta"); valueCell(meta)
                    }
                }
                if let notes = booking.userNotes, !notes.isEmpty {
                    GridRow {
                        labelCell("Notes"); valueCell(notes)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
    }
    
    private func mapSection(lat: Double, lon: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location Map").font(.headline)
            Map(coordinateRegion: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
    }
    
    private var actions: some View {
        HStack(spacing: 10) {
            Button("Contact Support") { /* open support */ }
                .buttonStyle(SecondaryButtonStyle())
            Button("Cancel Booking") { showCancelAlert = true }
                .buttonStyle(PrimaryButtonStyle())
                .tint(.red)
        }
        .alert("Cancel this booking?", isPresented: $showCancelAlert) {
            Button("Keep", role: .cancel) {}
            Button("Cancel Booking", role: .destructive) { cancelBooking() }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func labelCell(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    private func valueCell(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func iconForService(_ type: ServiceType) -> String {
        switch type {
        case .bodyguard: return "shield.lefthalf.fill"
        case .dronePatrol: return "airplane"
        case .surveillance: return "camera.viewfinder"
        case .escort: return "person.2.fill"
        case .emergency: return "cross.case.fill"
        }
    }
    private func serviceDisplayName(_ type: ServiceType) -> String {
        type.dbValue.replacingOccurrences(of: "_", with: " ")
    }
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f.string(from: date)
    }
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f.string(from: date)
    }
    
    private func progressForStatus(_ status: BookingStatus) -> Double {
        switch status {
        case .pending: return 0.25
        case .confirmed: return 0.5
        case .inProgress: return 0.75
        case .completed: return 1.0
        case .cancelled: return 0.0
        }
    }
    private func progressTitle(for status: BookingStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    private func colorForStatus(_ status: BookingStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Cancel booking API
extension BookingDetailView {
    private func currencyString(_ amount: Double, code: String?) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code ?? AppConfig.Payments.defaultCurrencyCode
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    private func cancelBooking() {
        Task {
            // Update booking status and payment status if needed
            do {
                try await SupabaseService.shared.updateBookingStatusAndPayment(id: booking.id, status: .cancelled, paymentStatus: booking.paymentStatus)
                NotificationHelper.schedule(title: "Booking Cancelled", body: "Your booking has been cancelled.")
            } catch {
                // Optionally present an error toast
            }
        }
    }
}
