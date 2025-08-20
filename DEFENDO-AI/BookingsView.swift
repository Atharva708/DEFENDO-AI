//
//  BookingsView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI

struct BookingsView: View {
    @EnvironmentObject var appState: AppState
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
                            .background(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color.white)
                
                // Bookings List
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(getFilteredBookings(), id: \.id) { booking in
                            BookingCard(booking: booking)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search bookings...")
        }
    }
    
    private func getFilteredBookings() -> [Booking] {
        // Mock data - in real app this would come from API
        let allBookings = [
            Booking(id: "1", serviceType: .securityGuard, provider: "Elite Security Services", date: Date().addingTimeInterval(86400), duration: 4, location: "Downtown Office", status: .confirmed, price: 100.0),
            Booking(id: "2", serviceType: .dronePatrol, provider: "SkyWatch Drones", date: Date().addingTimeInterval(-86400), duration: 2, location: "Residential Area", status: .completed, price: 70.0),
            Booking(id: "3", serviceType: .securityGuard, provider: "Guardian Protection", date: Date().addingTimeInterval(172800), duration: 8, location: "Corporate Building", status: .pending, price: 200.0),
            Booking(id: "4", serviceType: .dronePatrol, provider: "Aerial Security", date: Date().addingTimeInterval(-172800), duration: 1, location: "Shopping Mall", status: .cancelled, price: 35.0)
        ]
        
        switch selectedFilter {
        case "Upcoming":
            return allBookings.filter { $0.status == .pending || $0.status == .confirmed }
        case "In Progress":
            return allBookings.filter { $0.status == .inProgress }
        case "Completed":
            return allBookings.filter { $0.status == .completed }
        case "Cancelled":
            return allBookings.filter { $0.status == .cancelled }
        default:
            return allBookings
        }
    }
}

struct BookingCard: View {
    let booking: Booking
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: booking.serviceType == .securityGuard ? "person.2.fill" : "eye.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.provider)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(booking.serviceType == .securityGuard ? "Security Guard" : "Drone Patrol")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: booking.status)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "calendar", text: formatDate(booking.date))
                DetailRow(icon: "clock", text: "\(booking.duration) hours")
                DetailRow(icon: "location", text: booking.location)
                DetailRow(icon: "dollarsign.circle", text: "$\(String(format: "%.0f", booking.price))")
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

#Preview {
    BookingsView()
        .environmentObject(AppState())
}
