//
//  CommunityOverviewView.swift
//  DEFENDO-AI
//
//  Main community dashboard view
//

import SwiftUI

struct CommunityOverviewView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var communityService = CommunityService.shared
    @State private var community: Community?
    @State private var members: [CommunityMember] = []
    @State private var guardAssignments: [GuardAssignment] = []
    @State private var stats: (memberCount: Int, guardCount: Int, activeGuards: Int) = (0, 0, 0)
    @State private var isLoading = true
    @State private var showingInviteMember = false
    @State private var isUserAdmin = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading community...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let community = community {
                        // Community Header
                        NavigationLink(destination: CommunityDetailsView(community: community)
                            .environmentObject(authService)) {
                            CommunityHeaderCard(community: community, stats: stats)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Quick Actions
                        QuickActionsSection(
                            isUserAdmin: isUserAdmin,
                            onInviteMember: { showingInviteMember = true },
                            onViewMembers: { /* Navigate to members */ },
                            onViewGuards: { /* Navigate to guards */ }
                        )
                        
                        // Recent Activity
                        RecentActivityCard(guardAssignments: guardAssignments)
                        
                        // Members Preview
                        MembersPreviewCard(members: members)
                        
                    } else {
                        // No community found
                        NoCommunityView()
                    }
                }
                .padding()
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadCommunityData()
            }
            .sheet(isPresented: $showingInviteMember) {
                InviteMemberView(communityId: community?.id ?? UUID())
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
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
            // Load community
            community = try await communityService.fetchCommunity(for: userUUID)
            
            if let community = community {
                // Load community data
                async let membersTask = communityService.fetchCommunityMembers(communityId: community.id)
                async let guardsTask = communityService.fetchAssignedGuards(communityId: community.id)
                async let statsTask = communityService.getCommunityStats(communityId: community.id)
                async let adminTask = communityService.isUserAdmin(userId: userUUID, communityId: community.id)
                
                members = try await membersTask
                guardAssignments = try await guardsTask
                stats = try await statsTask
                isUserAdmin = try await adminTask
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load community: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Community Header Card

struct CommunityHeaderCard: View {
    let community: Community
    let stats: (memberCount: Int, guardCount: Int, activeGuards: Int)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(community.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = community.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "building.2.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            
            // Stats Row
            HStack(spacing: 20) {
                StatItem(title: "Members", value: "\(stats.memberCount)", icon: "person.2.fill", color: .green)
                StatItem(title: "Guards", value: "\(stats.guardCount)", icon: "shield.fill", color: .blue)
                StatItem(title: "Active", value: "\(stats.activeGuards)", icon: "checkmark.circle.fill", color: .orange)
            }
            
            if let address = community.address {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.trailing)
        )
    }
}


// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    let isUserAdmin: Bool
    let onInviteMember: () -> Void
    let onViewMembers: () -> Void
    let onViewGuards: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                if isUserAdmin {
                    QuickActionButton(
                        title: "Invite Member",
                        icon: "person.badge.plus",
                        color: .green,
                        action: onInviteMember
                    )
                }
                
                QuickActionButton(
                    title: "View Members",
                    icon: "person.2.fill",
                    color: .blue,
                    action: onViewMembers
                )
                
                QuickActionButton(
                    title: "View Guards",
                    icon: "shield.fill",
                    color: .orange,
                    action: onViewGuards
                )
                
                QuickActionButton(
                    title: "Activity",
                    icon: "clock.fill",
                    color: .purple,
                    action: { /* Navigate to activity */ }
                )
            }
        }
    }
}


// MARK: - Recent Activity Card

struct RecentActivityCard: View {
    let guardAssignments: [GuardAssignment]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Guard Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if guardAssignments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No recent activity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(guardAssignments.prefix(3)) { assignment in
                    ActivityRow(
                        action: "Guard \(assignment.status.capitalized)",
                        details: "\(assignment.guardInfo?.name ?? "Unknown Guard") • \(assignment.shift_start)–\(assignment.shift_end)",
                        time: assignment.assigned_date
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}



// MARK: - Members Preview Card

struct MembersPreviewCard: View {
    let members: [CommunityMember]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Community Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(members.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if members.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No members yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(members.prefix(3)) { member in
                    MemberRow(member: member)
                }
                
                if members.count > 3 {
                    HStack {
                        Spacer()
                        Text("+ \(members.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.top, 5)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


// MARK: - No Community View

struct NoCommunityView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Community Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You're not currently a member of any community. Contact your community administrator to get started.")
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
    CommunityOverviewView()
        .environmentObject(AuthService())
}

