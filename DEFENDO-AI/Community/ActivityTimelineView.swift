//
//  ActivityTimelineView.swift
//  DEFENDO-AI
//
//  Community activity timeline view
//

import SwiftUI

struct ActivityTimelineView: View {
    let communityId: UUID
    @StateObject private var communityService = CommunityService.shared
    @State private var guardAssignments: [GuardAssignment] = []
    @State private var allLogs: [GuardLog] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFilter = 0
    
    private let filters = ["All", "Check-ins", "Patrols", "Incidents"]
    
    var filteredLogs: [GuardLog] {
        switch selectedFilter {
        case 0: return allLogs
        case 1: return allLogs.filter { $0.log_type == "check_in" || $0.log_type == "check_out" }
        case 2: return allLogs.filter { $0.log_type == "patrol" }
        case 3: return allLogs.filter { $0.log_type == "incident" }
        default: return allLogs
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading activity...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allLogs.isEmpty {
                    EmptyActivityView()
                } else {
                    VStack(spacing: 0) {
                        // Filter Picker
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(0..<filters.count, id: \.self) { index in
                                Text(filters[index]).tag(index)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        // Timeline
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredLogs) { log in
                                    TimelineItem(log: log)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Activity Timeline")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadActivityData()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await loadActivityData()
        }
    }
    
    private func loadActivityData() async {
        do {
            // Get all guard assignments for the community
            guardAssignments = try await communityService.fetchAssignedGuards(communityId: communityId)
            
            // Get logs for all guards
            var allLogsTemp: [GuardLog] = []
            for assignment in guardAssignments {
                if let guardId = assignment.guardInfo?.id {
                    let logs = try await communityService.fetchGuardLogs(guardId: guardId)
                    allLogsTemp.append(contentsOf: logs)
                }
            }
            
            // Sort by timestamp (newest first)
            allLogs = allLogsTemp.sorted { $0.timestamp > $1.timestamp }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load activity: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let log: GuardLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(timelineColor)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(logTypeTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(formatDateTime(log.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: logTypeIcon)
                        .font(.title2)
                        .foregroundColor(timelineColor)
                }
                
                if let location = log.location {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
                
                if let lat = log.latitude, let lon = log.longitude {
                    HStack {
                        Image(systemName: "map")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.4f, %.4f", lat, lon))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.vertical, 8)
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
    
    private var logTypeTitle: String {
        switch log.log_type.lowercased() {
        case "check_in": return "Check In"
        case "check_out": return "Check Out"
        case "patrol": return "Patrol Activity"
        case "incident": return "Incident Report"
        default: return log.log_type.capitalized
        }
    }
    
    private var timelineColor: Color {
        switch log.log_type.lowercased() {
        case "check_in": return .green
        case "check_out": return .red
        case "patrol": return .blue
        case "incident": return .orange
        default: return .secondary
        }
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Empty Activity View

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Activity Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("There's no activity to show yet. Once guards start working, their activities will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Activity Summary Card

struct ActivitySummaryCard: View {
    let logs: [GuardLog]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Today's Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Check-ins",
                    count: logs.filter { $0.log_type == "check_in" }.count,
                    color: .green
                )
                
                SummaryItem(
                    title: "Patrols",
                    count: logs.filter { $0.log_type == "patrol" }.count,
                    color: .blue
                )
                
                SummaryItem(
                    title: "Incidents",
                    count: logs.filter { $0.log_type == "incident" }.count,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SummaryItem: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ActivityTimelineView(communityId: UUID())
}
