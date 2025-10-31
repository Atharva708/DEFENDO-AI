//
//  AdminDashboardView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AdminHomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            AdminUsersView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Users")
                }
                .tag(1)
            
            AdminProvidersView()
                .tabItem {
                    Image(systemName: "building.2.fill")
                    Text("Providers")
                }
                .tag(2)
            
            AdminReportsView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Reports")
                }
                .tag(3)
        }
    }
}

struct AdminHomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Platform Stats
                    PlatformStatsView()
                    
                    // Active Alerts
                    ActiveAlertsView()
                    
                    // Recent Activity
                    RecentActivityView()
                }
                .padding()
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct PlatformStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Platform Overview")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                AdminStatCard(title: "Total Users", value: "2,456", icon: "person.2.fill", color: .blue)
                AdminStatCard(title: "Active Providers", value: "89", icon: "building.2.fill", color: .green)
                AdminStatCard(title: "Active SOS", value: "3", icon: "exclamationmark.triangle.fill", color: .red)
                AdminStatCard(title: "Revenue", value: "$45,230", icon: "dollarsign.circle", color: .purple)
            }
        }
    }
}

struct AdminStatCard: View {
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

struct ActiveAlertsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Active SOS Alerts")
                .font(.headline)
            
            VStack(spacing: 10) {
                AlertRow(
                    user: "John Doe",
                    location: "Downtown Office",
                    time: "2 minutes ago",
                    status: "Active"
                )
                
                AlertRow(
                    user: "Sarah Smith",
                    location: "Residential Area",
                    time: "5 minutes ago",
                    status: "Responding"
                )
                
                AlertRow(
                    user: "Mike Johnson",
                    location: "Shopping Mall",
                    time: "8 minutes ago",
                    status: "Resolved"
                )
            }
        }
    }
}

struct AlertRow: View {
    let user: String
    let location: String
    let time: String
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(time)
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
        case "Active": return .red
        case "Responding": return .orange
        case "Resolved": return .green
        default: return .gray
        }
    }
}

struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Activity")
                .font(.headline)
            
            VStack(spacing: 10) {
                ActivityRow(
                    action: "New Provider Registration",
                    details: "Elite Security Services",
                    time: "10 minutes ago"
                )
                
                ActivityRow(
                    action: "SOS Alert Resolved",
                    details: "John Doe - Downtown Office",
                    time: "15 minutes ago"
                )
                
                ActivityRow(
                    action: "Payment Processed",
                    details: "$150 - Security Guard booking",
                    time: "20 minutes ago"
                )
            }
        }
    }
}

struct ActivityRow: View {
    let action: String
    let details: String
    let time: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AdminUsersView: View {
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    
    let filters = ["All", "Users", "Providers", "Admins"]
    
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
                
                // Users List
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(getUsers(), id: \.id) { user in
                            AdminUserCard(user: user)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search users...")
        }
    }
    
    private func getUsers() -> [AdminUser] {
        // Mock data
        return [
            AdminUser(id: "1", name: "John Doe", email: "john@email.com", role: "User", status: "Active", joinDate: "Jan 2024"),
            AdminUser(id: "2", name: "Elite Security", email: "contact@elite.com", role: "Provider", status: "Verified", joinDate: "Dec 2023"),
            AdminUser(id: "3", name: "Sarah Smith", email: "sarah@email.com", role: "User", status: "Active", joinDate: "Feb 2024"),
            AdminUser(id: "4", name: "SkyWatch Drones", email: "info@skywatch.com", role: "Provider", status: "Pending", joinDate: "Mar 2024")
        ]
    }
}

struct AdminUser: Identifiable {
    let id: String
    let name: String
    let email: String
    let role: String
    let status: String
    let joinDate: String
}

struct AdminUserCard: View {
    let user: AdminUser
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Joined: \(user.joinDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(user.role)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roleColor.opacity(0.2))
                    .foregroundColor(roleColor)
                    .cornerRadius(8)
                
                Text(user.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var roleColor: Color {
        switch user.role {
        case "User": return .blue
        case "Provider": return .green
        case "Admin": return .purple
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        switch user.status {
        case "Active": return .green
        case "Verified": return .blue
        case "Pending": return .orange
        default: return .gray
        }
    }
}

struct AdminProvidersView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(getProviders(), id: \.id) { provider in
                        AdminProviderCard(provider: provider)
                    }
                }
                .padding()
            }
            .navigationTitle("Providers")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func getProviders() -> [AdminProvider] {
        // Mock data
        return [
            AdminProvider(id: "1", name: "Elite Security Services", type: "Security", status: "Verified", rating: 4.8, bookings: 156),
            AdminProvider(id: "2", name: "SkyWatch Drones", type: "Drone", status: "Verified", rating: 4.9, bookings: 89),
            AdminProvider(id: "3", name: "Guardian Protection", type: "Security", status: "Pending", rating: 4.6, bookings: 67),
            AdminProvider(id: "4", name: "Aerial Security", type: "Drone", status: "Blocked", rating: 4.2, bookings: 23)
        ]
    }
}

struct AdminProvider: Identifiable {
    let id: String
    let name: String
    let type: String
    let status: String
    let rating: Double
    let bookings: Int
}

struct AdminProviderCard: View {
    let provider: AdminProvider
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(provider.type)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", provider.rating))
                            .font(.caption)
                    }
                    
                    Text(provider.status)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                }
            }
            
            HStack {
                Text("\(provider.bookings) bookings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button("View") {
                        // Handle view
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    if provider.status == "Pending" {
                        Button("Verify") {
                            // Handle verify
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch provider.status {
        case "Verified": return .green
        case "Pending": return .orange
        case "Blocked": return .red
        default: return .gray
        }
    }
}

struct AdminReportsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(getReports(), id: \.id) { report in
                        AdminReportCard(report: report)
                    }
                }
                .padding()
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func getReports() -> [AdminReport] {
        // Mock data
        return [
            AdminReport(id: "1", type: "Incident", title: "Suspicious Activity", reporter: "John Doe", status: "Investigating", date: "2 hours ago"),
            AdminReport(id: "2", type: "Dispute", title: "Service Quality Issue", reporter: "Sarah Smith", status: "Pending", date: "5 hours ago"),
            AdminReport(id: "3", type: "Incident", title: "Theft Report", reporter: "Mike Johnson", status: "Resolved", date: "1 day ago"),
            AdminReport(id: "4", type: "Dispute", title: "Payment Dispute", reporter: "Elite Security", status: "Pending", date: "2 days ago")
        ]
    }
}

struct AdminReport: Identifiable {
    let id: String
    let type: String
    let title: String
    let reporter: String
    let status: String
    let date: String
}

struct AdminReportCard: View {
    let report: AdminReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("Reported by: \(report.reporter)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(report.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(report.type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor.opacity(0.2))
                        .foregroundColor(typeColor)
                        .cornerRadius(8)
                    
                    Text(report.status)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 10) {
                Button("View Details") {
                    // Handle view details
                }
                .buttonStyle(PrimaryButtonStyle())
                
                if report.status == "Pending" {
                    Button("Resolve") {
                        // Handle resolve
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var typeColor: Color {
        switch report.type {
        case "Incident": return .red
        case "Dispute": return .orange
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        switch report.status {
        case "Pending": return .orange
        case "Investigating": return .blue
        case "Resolved": return .green
        default: return .gray
        }
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(AppState())
}
