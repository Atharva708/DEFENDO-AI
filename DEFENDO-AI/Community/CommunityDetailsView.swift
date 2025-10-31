//
//  CommunityDetailsView.swift
//  DEFENDO-AI
//
//  Community details page with invite member functionality
//

import SwiftUI

struct CommunityDetailsView: View {
    let community: Community
    @EnvironmentObject var authService: AuthService
    @StateObject private var communityService = CommunityService.shared
    @State private var members: [CommunityMember] = []
    @State private var guardAssignments: [GuardAssignment] = []
    @State private var stats: (memberCount: Int, guardCount: Int, activeGuards: Int) = (0, 0, 0)
    @State private var isLoading = true
    @State private var isUserAdmin = false
    @State private var showingInviteSheet = false
    @State private var showingMembersView = false
    @State private var showingGuardsView = false
    @State private var showingActivityView = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Community Header
                CommunityHeaderCard(community: community, stats: stats)
                
                // Admin Actions Section
                if isUserAdmin {
                    AdminActionsSection(
                        onInviteMember: { showingInviteSheet = true },
                        onViewMembers: { showingMembersView = true },
                        onViewGuards: { showingGuardsView = true },
                        onViewActivity: { showingActivityView = true }
                    )
                }
                
                // Quick Actions
                QuickActionsSection(
                    isUserAdmin: isUserAdmin,
                    onInviteMember: { showingInviteSheet = true },
                    onViewMembers: { showingMembersView = true },
                    onViewGuards: { showingGuardsView = true }
                )
                
                // Recent Activity
                RecentActivityCard(guardAssignments: guardAssignments)
                
                // Members Preview
                MembersPreviewCard(members: members)
            }
            .padding()
        }
        .navigationTitle(community.name)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadCommunityData()
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteMemberView(communityId: community.id)
        }
        .sheet(isPresented: $showingMembersView) {
            CommunityMembersView(communityId: community.id)
        }
        .sheet(isPresented: $showingGuardsView) {
            GuardsListView(communityId: community.id)
        }
        .sheet(isPresented: $showingActivityView) {
            ActivityTimelineView(communityId: community.id)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadCommunityData()
        }
    }
    
    private func loadCommunityData() async {
        guard let userId = authService.currentUser?.id,
              let userUUID = UUID(uuidString: userId) else {
            errorMessage = "User not found"
            isLoading = false
            return
        }
        
        do {
            // Load community data
            async let membersTask = communityService.fetchCommunityMembers(communityId: community.id)
            async let guardsTask = communityService.fetchAssignedGuards(communityId: community.id)
            async let statsTask = communityService.getCommunityStats(communityId: community.id)
            async let adminTask = communityService.isUserAdmin(userId: userUUID, communityId: community.id)
            
            members = try await membersTask
            guardAssignments = try await guardsTask
            stats = try await statsTask
            isUserAdmin = try await adminTask
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load community data: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Admin Actions Section

struct AdminActionsSection: View {
    let onInviteMember: () -> Void
    let onViewMembers: () -> Void
    let onViewGuards: () -> Void
    let onViewActivity: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("Admin Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                AdminActionButton(
                    title: "Invite Member",
                    icon: "person.badge.plus",
                    color: .green,
                    action: onInviteMember
                )
                
                AdminActionButton(
                    title: "Manage Members",
                    icon: "person.2.fill",
                    color: .blue,
                    action: onViewMembers
                )
                
                AdminActionButton(
                    title: "Manage Guards",
                    icon: "shield.fill",
                    color: .orange,
                    action: onViewGuards
                )
                
                AdminActionButton(
                    title: "View Activity",
                    icon: "clock.fill",
                    color: .purple,
                    action: onViewActivity
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


// MARK: - Guards List View (Placeholder)

struct GuardsListView: View {
    let communityId: UUID
    @StateObject private var communityService = CommunityService.shared
    @State private var guardAssignments: [GuardAssignment] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading guards...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if guardAssignments.isEmpty {
                    EmptyGuardsView()
                } else {
                    List {
                        ForEach(guardAssignments) { assignment in
                            GuardAssignmentRow(assignment: assignment)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Community Guards")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadGuards()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await loadGuards()
        }
    }
    
    private func loadGuards() async {
        do {
            guardAssignments = try await communityService.fetchAssignedGuards(communityId: communityId)
            isLoading = false
        } catch {
            errorMessage = "Failed to load guards: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct GuardAssignmentRow: View {
    let assignment: GuardAssignment
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: assignment.guardInfo?.photo_url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.guardInfo?.name ?? "Unknown Guard")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("\(assignment.assigned_date) • \(assignment.shift_start) - \(assignment.shift_end)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            GuardStatusBadge(status: assignment.status)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyGuardsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Guards Assigned")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This community doesn't have any guards assigned yet. Contact your community administrator to assign guards.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}


#Preview {
    CommunityDetailsView(community: Community(
        id: UUID(),
        name: "Sample Community",
        description: "A sample community for testing",
        address: "123 Main St, City, State",
        created_at: "2025-01-01T00:00:00Z",
        updated_at: "2025-01-01T00:00:00Z",
        admin_id: UUID()
    ))
    .environmentObject(AuthService())
}
