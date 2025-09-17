//
//  BookingsView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import Combine

struct BookingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var bookings: [BookingData] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var selectedFilter = "All"
    @State private var searchText = ""
    
    let filters = ["All", "Upcoming", "Completed", "Cancelled"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(filters, id: \.self) { filter in
                            Button(filter) {
                                selectedFilter = filter
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.blue : Color.black)
                            .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.8))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color.black)
                
                // Bookings List
                ScrollView {
                    if isLoading {
                        ProgressView().padding()
                    } else if let error = loadError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(.red)
                            Text(error).font(.footnote).foregroundColor(.secondary)
                            Button("Retry") { Task { await loadBookings() } }
                                .buttonStyle(PrimaryButtonStyle())
                        }.padding()
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(getFilteredBookings(), id: \.id) { booking in
                                BookingCardDynamic(booking: booking)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search bookings...")
            .onAppear { Task { await loadBookings() } }
        }
    }
    
    private func getFilteredBookings() -> [BookingData] {
        let all = bookings.filter { booking in
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            booking.location.localizedCaseInsensitiveContains(searchText) ||
            booking.serviceType.rawValue.localizedCaseInsensitiveContains(searchText)
        }
        switch selectedFilter {
        case "Upcoming":
            return all.filter { $0.status == .pending || $0.status == .confirmed }
        case "In Progress":
            return all.filter { $0.status == .inProgress }
        case "Completed":
            return all.filter { $0.status == .completed }
        case "Cancelled":
            return all.filter { $0.status == .cancelled }
        default:
            return all
        }
    }

    private func loadBookings() async {
        guard let userId = authService.currentUser?.id else { return }
        await MainActor.run { isLoading = true; loadError = nil }
        do {
            let result = try await SupabaseService.shared.getBookings(userId: userId)
            await MainActor.run { self.bookings = result; self.isLoading = false }
        } catch {
            await MainActor.run { self.loadError = error.localizedDescription; self.isLoading = false }
        }
    }
}

struct BookingCardDynamic: View {
    let booking: BookingData
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.providerId)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(booking.serviceType.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: booking.status)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "calendar", text: formatDate(booking.date))
                DetailRow(icon: "clock", text: "\(booking.durationHours) hours")
                DetailRow(icon: "location", text: booking.location)
                DetailRow(icon: "dollarsign.circle", text: currencyString(booking.price, code: nil))
            }
            
            // Actions
            HStack(spacing: 10) {
                if booking.status == .completed {
                    Button("Rebook") {
                        appState.currentScreen = .booking
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Button("View Details") {
                    // Show booking details
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: BookingStatus
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Currency helper
private func currencyString(_ amount: Double, code: String?) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    if let code = code { f.currencyCode = code }
    return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}

#Preview {
    BookingsView()
        .environmentObject(AppState())
}
