//
//  AuthService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import Foundation
import Supabase
import Combine

// MARK: - Database row model for Supabase "profiles" table
// Keep this as a plain DTO used only for decoding from Supabase.
// It is intentionally lightweight and non-isolated.
struct ProfileRow: Sendable {
    let id: UUID
    let email: String?
    let full_name: String?
    let phone: String?
    let created_at: Date
    let updated_at: Date
}

// Explicit nonisolated Codable conformance to avoid MainActor isolation
extension ProfileRow: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case full_name
        case phone
        case created_at
        case updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        full_name = try container.decodeIfPresent(String.self, forKey: .full_name)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        created_at = try container.decode(Date.self, forKey: .created_at)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(full_name, forKey: .full_name)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

// MARK: - AuthService
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var authError: String?
    @Published var authSuccess: String?
    @Published var allUsers: [User] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkCurrentSession()
    }
    
    // MARK: - Session Management
    func checkCurrentSession() {
        isLoading = true
        
        Task {
            do {
                let session = try await client.auth.session
                let userId = session.user.id
                // Fetch user profile from profiles table
                if let profile = try await fetchUserProfile(userId: userId) {
                    let mappedUser = mapProfileToUser(profile)
                    await MainActor.run {
                        self.currentUser = mappedUser
                        self.isAuthenticated = true
                        self.authError = nil
                        self.isLoading = false
                    }
                } else {
                    // No row in "profiles" table, fallback to Supabase user info
                    let user = session.user
                    await MainActor.run {
                        self.currentUser = User(
                            id: userId.uuidString,
                            name: user.userMetadata["full_name"]?.stringValue ?? "User",
                            email: user.email ?? "",
                            phone: user.phone ?? "",
                            role: .user,
                            safetyScore: 85
                        )
                        self.isAuthenticated = true
                        self.authError = nil
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String, phone: String) async {
        await MainActor.run {
            isLoading = true
            authError = nil
            authSuccess = nil
        }
        
        do {
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "full_name": AnyJSON.string(name),
                    "phone": AnyJSON.string(phone)
                ]
            )
            
            let user = authResponse.user
            
            // No accessToken or refreshToken available directly in authResponse (Supabase Swift SDK)
            
            await MainActor.run {
                self.currentUser = User(
                    id: user.id.uuidString,
                    name: name,
                    email: email,
                    phone: phone,
                    role: .user,
                    safetyScore: 85
                )
                self.isAuthenticated = true
                self.authSuccess = "Account created successfully! Please check your email to verify your account."
                self.isLoading = false
            }
            
            // Try to insert profile in background (don't block the UI)
            Task {
                do {
                    try await insertUserProfile(
                        id: user.id,
                        email: email,
                        fullName: name,
                        phone: phone
                    )
                    print("Profile created successfully")
                } catch {
                    print("Profile creation failed (non-critical): \(error.localizedDescription)")
                }
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            authError = nil
            authSuccess = nil
        }
        
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            let user = authResponse.user

            // NOTE: Saving tokens is skipped due to API structure. Adjust if tokens are available in authResponse.
            // _ = KeychainManager.shared.saveAuthToken(...)
            // _ = KeychainManager.shared.saveRefreshToken(...)

            // Immediately mark as logged in and navigate
            await MainActor.run {
                self.currentUser = User(
                    id: user.id.uuidString,
                    name: user.userMetadata["full_name"]?.stringValue ?? "User",
                    email: user.email ?? email,
                    phone: user.phone ?? "",
                    role: .user,
                    safetyScore: 85
                )
                self.isAuthenticated = true
                self.authSuccess = "Welcome back!"
                self.isLoading = false
            }

            // Fetch profile in background (non-blocking)
            Task {
                if let profile = try? await self.fetchUserProfile(userId: user.id) {
                    await MainActor.run {
                        self.currentUser = self.mapProfileToUser(profile)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await client.auth.signOut()
            
            // Clear secure storage
            KeychainManager.shared.deleteAllSecureData()
            
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.isLoading = false
                self.authSuccess = "Signed out successfully"
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async {
        await MainActor.run {
            isLoading = true
            authError = nil
            authSuccess = nil
        }
        
        do {
            try await client.auth.resetPasswordForEmail(email)
            
            await MainActor.run {
                self.authSuccess = "Password reset email sent. Please check your inbox."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(name: String, phone: String) async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        do {
            try await client.auth.update(user: UserAttributes(
                data: [
                    "full_name": AnyJSON.string(name),
                    "phone": AnyJSON.string(phone)
                ]
            ))
            // Update profiles table as well
            if let currentUser = self.currentUser {
                try await client
                    .from("profiles")
                    .update([
                        "full_name": name,
                        "phone": phone
                    ])
                    .eq("id", value: currentUser.id)
                    .execute()
            }
            
            await MainActor.run {
                if var user = self.currentUser {
                    user.name = name
                    user.phone = phone
                    self.currentUser = user
                }
                self.authSuccess = "Profile updated successfully"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch All Users (Admin)
    func fetchAllUsers() async {
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        do {
            let response: PostgrestResponse<[ProfileRow]> = try await client
                .from("profiles")
                .select()
                .execute()
            let profiles = response.value
            let users = profiles.map(mapProfileToUser)
            await MainActor.run {
                self.allUsers = users
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helpers: User Profile Table
    
    /// Insert user profile into 'profiles' table
    private func insertUserProfile(id: UUID, email: String, fullName: String, phone: String) async throws {
        _ = try await client
            .from("profiles")
            .insert([
                "id": id.uuidString,
                "email": email,
                "full_name": fullName,
                "phone": phone
            ])
            .execute()
    }
    
    /// Fetch user profile from 'profiles' table
    private func fetchUserProfile(userId: UUID) async throws -> ProfileRow? {
        do {
            let response: PostgrestResponse<ProfileRow> = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            return response.value
        } catch {
            print("Profile not found for user \(userId): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Map Profile to App User
    private func mapProfileToUser(_ profile: ProfileRow) -> User {
        User(
            id: profile.id.uuidString,
            name: profile.full_name ?? "User",
            email: profile.email ?? "",
            phone: profile.phone ?? "",
            role: .user,
            safetyScore: 85
        )
    }
    
    // MARK: - Test Database Connection
    func testDatabaseConnection() async {
        do {
            let response: PostgrestResponse<[String: String]> = try await client
                .from("profiles")
                .select("id")
                .limit(1)
                .execute()
            print("Database connection successful: \(response.value)")
        } catch {
            print("Database connection failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Clear Messages
    func clearMessages() {
        authError = nil
        authSuccess = nil
    }
}

