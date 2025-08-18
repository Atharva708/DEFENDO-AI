//
//  AuthService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import Foundation
import Supabase
import Combine

class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var authError: String?
    @Published var authSuccess: String?
    
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
                await MainActor.run {
                    let user = session.user
                    self.currentUser = User(
                        id: user.id.uuidString,
                        name: user.userMetadata["name"]?.stringValue ?? "User",
                        email: user.email ?? "",
                        phone: user.phone ?? "",
                        role: .user,
                        safetyScore: 85
                    )
                    self.isAuthenticated = true
                    self.authError = nil
                    self.isLoading = false
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
                    "name": AnyJSON.string(name),
                    "phone": AnyJSON.string(phone)
                ]
            )
            
            await MainActor.run {
                let user = authResponse.user
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
            
            await MainActor.run {
                let user = authResponse.user
                self.currentUser = User(
                    id: user.id.uuidString,
                    name: user.userMetadata["name"]?.stringValue ?? "User",
                    email: user.email ?? "",
                    phone: user.phone ?? "",
                    role: .user,
                    safetyScore: 85
                )
                self.isAuthenticated = true
                self.authSuccess = "Welcome back!"
                self.isLoading = false
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
                    "name": AnyJSON.string(name),
                    "phone": AnyJSON.string(phone)
                ]
            ))
            
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
    
    // MARK: - Clear Messages
    func clearMessages() {
        authError = nil
        authSuccess = nil
    }
}
