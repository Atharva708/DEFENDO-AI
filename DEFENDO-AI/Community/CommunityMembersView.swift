//
//  CommunityMembersView.swift
//  DEFENDO-AI
//
//  Community members management view
//

import SwiftUI

struct CommunityMembersView: View {
    let communityId: UUID
    @StateObject private var communityService = CommunityService.shared
    @State private var members: [CommunityMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var filteredMembers: [CommunityMember] {
        if searchText.isEmpty {
            return members
        } else {
            return members.filter { member in
                member.user_profile?.full_name?.localizedCaseInsensitiveContains(searchText) == true ||
                member.user_profile?.email?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading members...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if members.isEmpty {
                    EmptyMembersView()
                } else {
                    List {
                        ForEach(filteredMembers) { member in
                            MemberDetailRow(member: member)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .searchable(text: $searchText, prompt: "Search members")
                }
            }
            .navigationTitle("Community Members")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadMembers()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        do {
            members = try await communityService.fetchCommunityMembers(communityId: communityId)
            isLoading = false
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct MemberDetailRow: View {
    let member: CommunityMember
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Image
            AsyncImage(url: URL(string: "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Member Info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.user_profile?.full_name ?? "Unknown User")
                    .font(.headline)
                    .fontWeight(.medium)
                
                if let email = member.user_profile?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let phone = member.user_profile?.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Role Badge
            VStack(spacing: 5) {
                RoleBadge(role: member.role)
                
                Text("Joined \(formatDate(member.joined_at))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

struct RoleBadge: View {
    let role: String
    
    var body: some View {
        HStack(spacing: 4) {
            if role == "admin" {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
            
            Text(role.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(roleColor.opacity(0.2))
                .foregroundColor(roleColor)
                .cornerRadius(6)
        }
    }
    
    private var roleColor: Color {
        switch role.lowercased() {
        case "admin": return .yellow
        case "member": return .blue
        default: return .secondary
        }
    }
}

struct EmptyMembersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Members Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This community doesn't have any members yet. Invite people to join your community.")
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
    CommunityMembersView(communityId: UUID())
}
