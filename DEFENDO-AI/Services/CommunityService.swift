//
//  CommunityService.swift
//  DEFENDO-AI
//
//  Community management service for Supabase integration
//

import Foundation
import Supabase
import Combine

// MARK: - Community Data Models

struct Community: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let address: String?
    let created_at: String
    let updated_at: String
    let admin_id: UUID
}

struct CommunityMember: Identifiable, Sendable {
    let id: UUID
    let community_id: UUID
    let user_id: UUID
    let role: String // "admin" or "member"
    let joined_at: String
    let user_profile: UserProfile?
}

struct UserProfile: Sendable {
    let id: UUID
    let email: String?
    let full_name: String?
    let phone: String?
    let role: String?
    let safety_score: Int?
}

struct Guard: Identifiable, Sendable {
    let id: UUID
    let name: String
    let phone: String
    let email: String?
    let photo_url: String?
    let shift_start_time: String // HH:mm format
    let shift_end_time: String // HH:mm format
    let status: String // "active", "inactive", "on_duty"
    let created_at: String
    let updated_at: String
}

struct GuardAssignment: Identifiable, Sendable {
    let id: UUID
    let community_id: UUID
    let guard_id: UUID
    let assigned_date: String // yyyy-MM-dd
    let shift_start: String // HH:mm
    let shift_end: String // HH:mm
    let status: String // "scheduled", "active", "completed", "cancelled"
    let created_at: String
    let guardInfo: Guard?
}

struct GuardLog: Identifiable, Sendable {
    let id: UUID
    let guard_id: UUID
    let community_id: UUID
    let log_type: String // "check_in", "check_out", "patrol", "incident"
    let timestamp: String
    let location: String?
    let notes: String?
    let latitude: Double?
    let longitude: Double?
    let created_at: String
}

struct GuardHoliday: Identifiable, Sendable {
    let id: UUID
    let guard_id: UUID
    let start_date: String // yyyy-MM-dd
    let end_date: String // yyyy-MM-dd
    let reason: String?
    let substitute_guard_id: UUID?
    let status: String // "approved", "pending", "rejected"
    let created_at: String
    let substitute_guard: Guard?
}

// MARK: - Database Row Models

struct CommunityMemberRow: Sendable {
    let community_id: UUID
}

// Insert/Update Models

struct CommunityInsert: Sendable {
    let name: String
    let description: String?
    let address: String?
    let admin_id: UUID
}

struct CommunityMemberInsert: Sendable {
    let community_id: UUID
    let user_id: UUID
    let role: String
}

struct InviteMemberRequest: Sendable {
    let email: String
    let community_id: UUID
    let role: String
}

// MARK: - Community Service

class CommunityService: ObservableObject {
    static let shared = CommunityService()
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    // MARK: - Community Operations
    
    /// Fetch community linked to current user
    func fetchCommunity(for userId: UUID) async throws -> Community? {
        // First get the community_id from community_members
        let memberResponse: PostgrestResponse<CommunityMemberRow> = try await client
            .from("community_members")
            .select("community_id")
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
        
        let member = memberResponse.value
        
        // Then fetch the community details
        let communityResponse: PostgrestResponse<Community> = try await client
            .from("communities")
            .select()
            .eq("id", value: member.community_id.uuidString)
            .single()
            .execute()
        
        return communityResponse.value
    }
    
    /// Create a new community and add the creator as admin member
    func createCommunity(name: String, description: String?, address: String?, adminId: UUID) async throws -> Community {
        // Insert community
        let insert = CommunityInsert(name: name, description: description, address: address, admin_id: adminId)
        let communityResponse: PostgrestResponse<Community> = try await client
            .from("communities")
            .insert(insert)
            .select()
            .single()
            .execute()
        let community = communityResponse.value
        
        // Add admin as member
        let memberData = CommunityMemberInsert(
            community_id: community.id,
            user_id: adminId,
            role: "admin"
        )
        _ = try await client
            .from("community_members")
            .insert(memberData)
            .execute()
        
        return community
    }
    
    /// Fetch all members in a community with their profiles
    func fetchCommunityMembers(communityId: UUID) async throws -> [CommunityMember] {
        let response: PostgrestResponse<[CommunityMember]> = try await client
            .from("community_members")
            .select("*, user_profile:users(*)")
            .eq("community_id", value: communityId.uuidString)
            .order("joined_at", ascending: true)
            .execute()
        
        return response.value
    }
    
    /// Invite a member to the community by email
    func inviteMember(email: String, communityId: UUID) async throws {
        // First, find the user by email
        let userResponse: PostgrestResponse<UserProfile> = try await client
            .from("users")
            .select()
            .eq("email", value: email)
            .single()
            .execute()
        
        let user = userResponse.value
        
        // Check if user is already a member
        let existingMemberResponse: PostgrestResponse<[CommunityMember]> = try await client
            .from("community_members")
            .select()
            .eq("community_id", value: communityId.uuidString)
            .eq("user_id", value: user.id.uuidString)
            .execute()
        
        if !existingMemberResponse.value.isEmpty {
            throw NSError(domain: "CommunityService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User is already a member of this community"])
        }
        
        // Add user to community
        let memberData = CommunityMemberInsert(
            community_id: communityId,
            user_id: user.id,
            role: "member"
        )
        
        _ = try await client
            .from("community_members")
            .insert(memberData)
            .execute()
    }
    
    /// Invite a member to the community by phone number
    func inviteMemberByPhone(phoneNumber: String, communityId: UUID) async throws {
        // First, find the user by phone number
        let userResponse: PostgrestResponse<UserProfile> = try await client
            .from("users")
            .select()
            .eq("phone", value: phoneNumber)
            .single()
            .execute()
        
        let user = userResponse.value
        
        // Check if user is already a member
        let existingMemberResponse: PostgrestResponse<[CommunityMember]> = try await client
            .from("community_members")
            .select()
            .eq("community_id", value: communityId.uuidString)
            .eq("user_id", value: user.id.uuidString)
            .execute()
        
        if !existingMemberResponse.value.isEmpty {
            throw NSError(domain: "CommunityService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User is already a member of this community"])
        }
        
        // Add user to community
        let memberData = CommunityMemberInsert(
            community_id: communityId,
            user_id: user.id,
            role: "member"
        )
        
        _ = try await client
            .from("community_members")
            .insert(memberData)
            .execute()
    }
    
    // MARK: - Guard Operations
    
    /// Fetch assigned guards for a community
    func fetchAssignedGuards(communityId: UUID) async throws -> [GuardAssignment] {
        let response: PostgrestResponse<[GuardAssignment]> = try await client
            .from("guard_assignments")
            .select("*, guardInfo:guards(*)")
            .eq("community_id", value: communityId.uuidString)
            .order("assigned_date", ascending: false)
            .execute()
        
        return response.value
    }
    
    /// Fetch guard logs (attendance/activity records)
    func fetchGuardLogs(guardId: UUID) async throws -> [GuardLog] {
        let response: PostgrestResponse<[GuardLog]> = try await client
            .from("guard_logs")
            .select()
            .eq("guard_id", value: guardId.uuidString)
            .order("timestamp", ascending: false)
            .execute()
        
        return response.value
    }
    
    /// Fetch guard holidays (planned absences + substitutes)
    func fetchGuardHolidays(guardId: UUID) async throws -> [GuardHoliday] {
        let response: PostgrestResponse<[GuardHoliday]> = try await client
            .from("guard_holidays")
            .select("*, substitute_guard:guards(*)")
            .eq("guard_id", value: guardId.uuidString)
            .order("start_date", ascending: false)
            .execute()
        
        return response.value
    }
    
    /// Get guard details by ID
    func fetchGuardDetails(guardId: UUID) async throws -> Guard? {
        let response: PostgrestResponse<Guard> = try await client
            .from("guards")
            .select()
            .eq("id", value: guardId.uuidString)
            .single()
            .execute()
        
        return response.value
    }
    
    // MARK: - Helper Methods
    
    /// Check if current user is admin of a community
    func isUserAdmin(userId: UUID, communityId: UUID) async throws -> Bool {
        let response: PostgrestResponse<[CommunityMember]> = try await client
            .from("community_members")
            .select()
            .eq("community_id", value: communityId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("role", value: "admin")
            .execute()
        
        return !response.value.isEmpty
    }
    
    /// Get community statistics
    func getCommunityStats(communityId: UUID) async throws -> (memberCount: Int, guardCount: Int, activeGuards: Int) {
        // Get member count
        let memberResponse: PostgrestResponse<[CommunityMember]> = try await client
            .from("community_members")
            .select("id")
            .eq("community_id", value: communityId.uuidString)
            .execute()
        
        // Get guard assignments count
        let guardResponse: PostgrestResponse<[GuardAssignment]> = try await client
            .from("guard_assignments")
            .select("id, status")
            .eq("community_id", value: communityId.uuidString)
            .execute()
        
        let memberCount = memberResponse.value.count
        let guardCount = guardResponse.value.count
        let activeGuards = guardResponse.value.filter { $0.status == "active" }.count
        
        return (memberCount: memberCount, guardCount: guardCount, activeGuards: activeGuards)
    }
}

// MARK: - Extensions for Date Formatting

extension CommunityService {
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
}

// MARK: - Explicit nonisolated Codable conformance to avoid MainActor isolation

extension Community: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, address, created_at, updated_at, admin_id
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try container.decode(String.self, forKey: .updated_at)
        admin_id = try container.decode(UUID.self, forKey: .admin_id)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encode(admin_id, forKey: .admin_id)
    }
}

extension CommunityMember: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, community_id, user_id, role, joined_at, user_profile
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        community_id = try container.decode(UUID.self, forKey: .community_id)
        user_id = try container.decode(UUID.self, forKey: .user_id)
        role = try container.decode(String.self, forKey: .role)
        joined_at = try container.decode(String.self, forKey: .joined_at)
        user_profile = try container.decodeIfPresent(UserProfile.self, forKey: .user_profile)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(community_id, forKey: .community_id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(role, forKey: .role)
        try container.encode(joined_at, forKey: .joined_at)
        try container.encodeIfPresent(user_profile, forKey: .user_profile)
    }
}

extension UserProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, email, full_name, phone, role, safety_score
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        safety_score = try container.decodeIfPresent(Int.self, forKey: .safety_score)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(full_name, forKey: .full_name)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(safety_score, forKey: .safety_score)
    }
}

extension Guard: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, phone, email, photo_url, shift_start_time, shift_end_time, status, created_at, updated_at
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        phone = try container.decode(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        photo_url = try container.decodeIfPresent(String.self, forKey: .photo_url)
        shift_start_time = try container.decode(String.self, forKey: .shift_start_time)
        shift_end_time = try container.decode(String.self, forKey: .shift_end_time)
        status = try container.decode(String.self, forKey: .status)
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try container.decode(String.self, forKey: .updated_at)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(photo_url, forKey: .photo_url)
        try container.encode(shift_start_time, forKey: .shift_start_time)
        try container.encode(shift_end_time, forKey: .shift_end_time)
        try container.encode(status, forKey: .status)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

extension GuardAssignment: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, community_id, guard_id, assigned_date, shift_start, shift_end, status, created_at, guardInfo
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        community_id = try container.decode(UUID.self, forKey: .community_id)
        guard_id = try container.decode(UUID.self, forKey: .guard_id)
        assigned_date = try container.decode(String.self, forKey: .assigned_date)
        shift_start = try container.decode(String.self, forKey: .shift_start)
        shift_end = try container.decode(String.self, forKey: .shift_end)
        status = try container.decode(String.self, forKey: .status)
        created_at = try container.decode(String.self, forKey: .created_at)
        guardInfo = try container.decodeIfPresent(Guard.self, forKey: .guardInfo)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(community_id, forKey: .community_id)
        try container.encode(guard_id, forKey: .guard_id)
        try container.encode(assigned_date, forKey: .assigned_date)
        try container.encode(shift_start, forKey: .shift_start)
        try container.encode(shift_end, forKey: .shift_end)
        try container.encode(status, forKey: .status)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(guardInfo, forKey: .guardInfo)
    }
}

extension GuardLog: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, guard_id, community_id, log_type, timestamp, location, notes, latitude, longitude, created_at
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        guard_id = try container.decode(UUID.self, forKey: .guard_id)
        community_id = try container.decode(UUID.self, forKey: .community_id)
        log_type = try container.decode(String.self, forKey: .log_type)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        created_at = try container.decode(String.self, forKey: .created_at)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(guard_id, forKey: .guard_id)
        try container.encode(community_id, forKey: .community_id)
        try container.encode(log_type, forKey: .log_type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(created_at, forKey: .created_at)
    }
}

extension GuardHoliday: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, guard_id, start_date, end_date, reason, substitute_guard_id, status, created_at, substitute_guard
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        guard_id = try container.decode(UUID.self, forKey: .guard_id)
        start_date = try container.decode(String.self, forKey: .start_date)
        end_date = try container.decode(String.self, forKey: .end_date)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        substitute_guard_id = try container.decodeIfPresent(UUID.self, forKey: .substitute_guard_id)
        status = try container.decode(String.self, forKey: .status)
        created_at = try container.decode(String.self, forKey: .created_at)
        substitute_guard = try container.decodeIfPresent(Guard.self, forKey: .substitute_guard)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(guard_id, forKey: .guard_id)
        try container.encode(start_date, forKey: .start_date)
        try container.encode(end_date, forKey: .end_date)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(substitute_guard_id, forKey: .substitute_guard_id)
        try container.encode(status, forKey: .status)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(substitute_guard, forKey: .substitute_guard)
    }
}

extension CommunityMemberRow: Codable {
    private enum CodingKeys: String, CodingKey {
        case community_id
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        community_id = try container.decode(UUID.self, forKey: .community_id)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(community_id, forKey: .community_id)
    }
}

extension CommunityInsert: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, address, admin_id
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        admin_id = try container.decode(UUID.self, forKey: .admin_id)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(admin_id, forKey: .admin_id)
    }
}

extension CommunityMemberInsert: Codable {
    private enum CodingKeys: String, CodingKey {
        case community_id, user_id, role
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        community_id = try container.decode(UUID.self, forKey: .community_id)
        user_id = try container.decode(UUID.self, forKey: .user_id)
        role = try container.decode(String.self, forKey: .role)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(community_id, forKey: .community_id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(role, forKey: .role)
    }
}

extension InviteMemberRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case email, community_id, role
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        community_id = try container.decode(UUID.self, forKey: .community_id)
        role = try container.decode(String.self, forKey: .role)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(community_id, forKey: .community_id)
        try container.encode(role, forKey: .role)
    }
}

