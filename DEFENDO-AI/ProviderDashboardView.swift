//
//  ProviderDashboardView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI

struct ProviderDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProviderHomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            ProviderBookingsView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Bookings")
                }
                .tag(1)
            
            ProviderAnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Analytics")
                }
                .tag(2)
            
            ProviderProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(3)
        }
    }
}

struct ProviderHomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    StatsGridView()
                    
                    // Quick Actions
                    QuickActionsView()
                    
                    // Recent Bookings
                    RecentBookingsView()
                    
                    // Availability Toggle
                    AvailabilityToggleView()
                }
                .padding()
            }
            .navigationTitle("Provider Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct StatsGridView: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
            StatCard(title: "Total Bookings", value: "156", icon: "calendar", color: .blue)
            StatCard(title: "Earnings", value: "$3,240", icon: "dollarsign.circle", color: .green)
            StatCard(title: "Reviews", value: "4.8★", icon: "star.fill", color: .yellow)
            StatCard(title: "Active Services", value: "3", icon: "person.2.fill", color: .orange)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                ProviderQuickActionCard(icon: "plus.circle", title: "Add Drone", color: .blue)
                ProviderQuickActionCard(icon: "person.badge.plus", title: "Add Guard", color: .green)
                ProviderQuickActionCard(icon: "photo.on.rectangle", title: "Manage Portfolio", color: .orange)
                ProviderQuickActionCard(icon: "gear", title: "Settings", color: .purple)
            }
        }
    }
}

struct ProviderQuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {
            // Handle action
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentBookingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Bookings")
                .font(.headline)
            
            VStack(spacing: 10) {
                ProviderBookingRow(
                    service: "Security Guard",
                    client: "John Doe",
                    date: "Today, 2:30 PM",
                    status: "Confirmed"
                )
                
                ProviderBookingRow(
                    service: "Drone Patrol",
                    client: "Sarah Smith",
                    date: "Tomorrow, 10:00 AM",
                    status: "Pending"
                )
                
                ProviderBookingRow(
                    service: "Security Guard",
                    client: "Mike Johnson",
                    date: "Yesterday, 8:00 PM",
                    status: "Completed"
                )
            }
        }
    }
}

struct ProviderBookingRow: View {
    let service: String
    let client: String
    let date: String
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(client)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch status {
        case "Confirmed": return .blue
        case "Pending": return .orange
        case "Completed": return .green
        default: return .gray
        }
    }
}

struct AvailabilityToggleView: View {
    @State private var isAvailable = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Availability")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAvailable ? "Available" : "Unavailable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(isAvailable ? "Accepting new bookings" : "Not accepting bookings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isAvailable)
                    .labelsHidden()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct ProviderBookingsView: View {
    @State private var selectedFilter = "All"
    
    let filters = ["All", "Pending", "Confirmed", "Completed", "Cancelled"]
    
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
                        ForEach(getProviderBookings(), id: \.id) { booking in
                            ProviderBookingCard(booking: booking)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Bookings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func getProviderBookings() -> [ProviderBooking] {
        // Mock data
        return [
            ProviderBooking(id: "1", service: "Security Guard", client: "John Doe", date: Date().addingTimeInterval(86400), duration: 4, location: "Downtown Office", status: "Confirmed", price: 100.0),
            ProviderBooking(id: "2", service: "Drone Patrol", client: "Sarah Smith", date: Date().addingTimeInterval(172800), duration: 2, location: "Residential Area", status: "Pending", price: 70.0),
            ProviderBooking(id: "3", service: "Security Guard", client: "Mike Johnson", date: Date().addingTimeInterval(-86400), duration: 8, location: "Corporate Building", status: "Completed", price: 200.0)
        ]
    }
}

struct ProviderBooking: Identifiable {
    let id: String
    let service: String
    let client: String
    let date: Date
    let duration: Int
    let location: String
    let status: String
    let price: Double
}

struct ProviderBookingCard: View {
    let booking: ProviderBooking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.service)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(booking.client)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(booking.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "calendar", text: formatDate(booking.date))
                DetailRow(icon: "clock", text: "\(booking.duration) hours")
                DetailRow(icon: "location", text: booking.location)
                DetailRow(icon: "dollarsign.circle", text: "$\(String(format: "%.0f", booking.price))")
            }
            
            HStack(spacing: 10) {
                if booking.status == "Pending" {
                    Button("Accept") {
                        // Handle accept
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Decline") {
                        // Handle decline
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("View Details") {
                        // Show details
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
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
    
    private var statusColor: Color {
        switch booking.status {
        case "Confirmed": return .blue
        case "Pending": return .orange
        case "Completed": return .green
        case "Cancelled": return .red
        default: return .gray
        }
    }
}

struct ProviderAnalyticsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Revenue Chart
                    RevenueChartView()
                    
                    // Performance Metrics
                    PerformanceMetricsView()
                    
                    // Top Services
                    TopServicesView()
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct RevenueChartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Revenue This Month")
                .font(.headline)
            
            // Placeholder for chart
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Text("$3,240")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("+12% from last month")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                )
                .cornerRadius(12)
        }
    }
}

struct PerformanceMetricsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Performance Metrics")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                MetricCard(title: "Completion Rate", value: "98%", color: .green)
                MetricCard(title: "Response Time", value: "2.3 min", color: .blue)
                MetricCard(title: "Customer Rating", value: "4.8★", color: .yellow)
                MetricCard(title: "Repeat Clients", value: "45%", color: .purple)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TopServicesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Top Performing Services")
                .font(.headline)
            
            VStack(spacing: 10) {
                ServicePerformanceRow(service: "Security Guard", bookings: 89, revenue: "$2,225")
                ServicePerformanceRow(service: "Drone Patrol", bookings: 45, revenue: "$1,575")
                ServicePerformanceRow(service: "Event Security", bookings: 22, revenue: "$1,100")
            }
        }
    }
}

struct ServicePerformanceRow: View {
    let service: String
    let bookings: Int
    let revenue: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(bookings) bookings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(revenue)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProviderProfileView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    ProviderProfileHeaderView()
                    
                    // Services Section
                    ServicesSectionView()
                    
                    // Settings Section
                    ProviderSettingsSectionView()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProviderProfileHeaderView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 5) {
                Text("Elite Security Services")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Verified Provider")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("Security Services • 5 years")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Rating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("4.8★")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total Bookings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("156")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ServicesSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Services")
                .font(.headline)
            
            VStack(spacing: 10) {
                ServiceRow(service: "Security Guard", price: "$25/hr", status: "Active")
                ServiceRow(service: "Drone Patrol", price: "$35/hr", status: "Active")
                ServiceRow(service: "Event Security", price: "$40/hr", status: "Active")
            }
        }
    }
}

struct ServiceRow: View {
    let service: String
    let price: String
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(price)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProviderSettingsSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Settings")
                .font(.headline)
            
            VStack(spacing: 0) {
                SettingsRow(icon: "building.2.fill", title: "Company Profile", subtitle: "Update business information")
                SettingsRow(icon: "creditcard.fill", title: "Payment Settings", subtitle: "Manage payouts")
                SettingsRow(icon: "bell.fill", title: "Notifications", subtitle: "Manage alerts")
                SettingsRow(icon: "shield.fill", title: "Verification", subtitle: "KYC & Documents")
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    ProviderDashboardView()
        .environmentObject(AppState())
}
