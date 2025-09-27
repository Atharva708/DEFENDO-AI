//
//  GuardDetailView.swift
//  DEFENDO-AI
//
//  Guard details and activity view
//

import SwiftUI

struct GuardDetailView: View {
    let guardId: UUID
    @StateObject private var communityService = CommunityService.shared
    @State private var guardDetails: Guard?
    @State private var logs: [GuardLog] = []
    @State private var holidays: [GuardHoliday] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading guard details...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let guardDetails = guardDetails {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Guard Header
                            GuardHeaderCard(guardInfo: guardDetails)
                            
                            // Tab Selector
                            Picker("View", selection: $selectedTab) {
                                Text("Logs").tag(0)
                                Text("Holidays").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            
                            // Content based on selected tab
                            if selectedTab == 0 {
                                GuardLogsView(logs: logs)
                            } else {
                                GuardHolidaysView(holidays: holidays)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("Guard not found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(guardDetails?.name ?? "Guard Details")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadGuardData()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await loadGuardData()
        }
    }
    
    private func loadGuardData() async {
        do {
            async let guardTask = communityService.fetchGuardDetails(guardId: guardId)
            async let logsTask = communityService.fetchGuardLogs(guardId: guardId)
            async let holidaysTask = communityService.fetchGuardHolidays(guardId: guardId)
            
            guardDetails = try await guardTask
            logs = try await logsTask
            holidays = try await holidaysTask
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load guard data: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Guard Header Card

struct GuardHeaderCard: View {
    let guardInfo: Guard
    
    var body: some View {
        VStack(spacing: 15) {
            // Profile Image
            AsyncImage(url: URL(string: guardInfo.photo_url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            // Guard Info
            VStack(spacing: 5) {
                Text(guardInfo.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let email = guardInfo.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(guardInfo.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Status and Shift Info
            HStack(spacing: 20) {
                VStack(spacing: 5) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    GuardStatusBadge(status: guardInfo.status)
                }
                
                VStack(spacing: 5) {
                    Text("Shift")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(guardInfo.shift_start_time) - \(guardInfo.shift_end_time)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Guard Logs View

struct GuardLogsView: View {
    let logs: [GuardLog]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Activity Logs")
                .font(.headline)
                .fontWeight(.semibold)
            
            if logs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No activity logs yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(logs) { log in
                    LogRow(log: log)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LogRow: View {
    let log: GuardLog
    
    var body: some View {
        HStack {
            // Log Type Icon
            Image(systemName: logTypeIcon)
                .font(.title3)
                .foregroundColor(logTypeColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(logTypeTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let location = log.location {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = log.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDateTime(log.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lat = log.latitude, let lon = log.longitude {
                    Text("📍 \(String(format: "%.4f, %.4f", lat, lon))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var logTypeIcon: String {
        switch log.log_type.lowercased() {
        case "check_in": return "arrow.down.circle.fill"
        case "check_out": return "arrow.up.circle.fill"
        case "patrol": return "figure.walk"
        case "incident": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }
    
    private var logTypeColor: Color {
        switch log.log_type.lowercased() {
        case "check_in": return .green
        case "check_out": return .red
        case "patrol": return .blue
        case "incident": return .orange
        default: return .secondary
        }
    }
    
    private var logTypeTitle: String {
        switch log.log_type.lowercased() {
        case "check_in": return "Check In"
        case "check_out": return "Check Out"
        case "patrol": return "Patrol"
        case "incident": return "Incident Report"
        default: return log.log_type.capitalized
        }
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Guard Holidays View

struct GuardHolidaysView: View {
    let holidays: [GuardHoliday]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Holidays & Leave")
                .font(.headline)
                .fontWeight(.semibold)
            
            if holidays.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.minus")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No holidays scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(holidays) { holiday in
                    HolidayRow(holiday: holiday)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HolidayRow: View {
    let holiday: GuardHoliday
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatDate(holiday.start_date)) - \(formatDate(holiday.end_date))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let reason = holiday.reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                GuardStatusBadge(status: holiday.status)
            }
            
            if let substitute = holiday.substitute_guard {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Substitute: \(substitute.name)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}


#Preview {
    GuardDetailView(guardId: UUID())
}
