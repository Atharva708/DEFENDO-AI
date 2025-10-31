//
//  LegalAgreementManager.swift
//  DEFENDO-AI
//
//  Manages legal agreement flow for new users
//

import SwiftUI

struct LegalAgreementManager: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLegalAgreement = false
    @State private var hasCheckedLegalStatus = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated && !hasCheckedLegalStatus {
                // Check legal status when user is authenticated
                Color.clear
                    .onAppear {
                        checkLegalStatus()
                    }
            } else if authService.isAuthenticated && hasCheckedLegalStatus {
                // User is authenticated and legal status is checked
                if showingLegalAgreement {
                    LegalAgreementView(
                        userId: authService.currentUser?.id ?? "",
                        onAcceptance: {
                            showingLegalAgreement = false
                            Task {
                                await authService.recordLegalAcceptance()
                            }
                        }
                    )
                } else {
                    // User has accepted legal terms, show main app
                    DashboardView()
                }
            } else {
                // User is not authenticated, show authentication
                AuthenticationContainerView()
            }
        }
    }
    
    private func checkLegalStatus() {
        guard let userId = authService.currentUser?.id else {
            hasCheckedLegalStatus = true
            return
        }
        
        // Check if user has accepted legal terms
        let hasAcceptedLegal = UserDefaults.standard.bool(forKey: "user_legal_accepted_\(userId)")
        
        if !hasAcceptedLegal {
            // Show legal agreement for new users
            showingLegalAgreement = true
        }
        
        hasCheckedLegalStatus = true
    }
}

// MARK: - Legal Agreement Wrapper
struct LegalAgreementWrapper: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLegalAgreement = false
    
    var body: some View {
        Group {
            if showingLegalAgreement {
                LegalAgreementView(
                    userId: authService.currentUser?.id ?? "",
                    onAcceptance: {
                        showingLegalAgreement = false
                        Task {
                            await authService.recordLegalAcceptance()
                        }
                    }
                )
            } else {
                // Show the wrapped content
                DashboardView()
            }
        }
        .onAppear {
            checkIfLegalAgreementNeeded()
        }
    }
    
    private func checkIfLegalAgreementNeeded() {
        guard let userId = authService.currentUser?.id else { return }
        
        let hasAcceptedLegal = UserDefaults.standard.bool(forKey: "user_legal_accepted_\(userId)")
        
        if !hasAcceptedLegal {
            showingLegalAgreement = true
        }
    }
}

// MARK: - Legal Agreement Button (for settings)
struct LegalAgreementButton: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLegalAgreement = false
    
    var body: some View {
        Button("View Terms & Privacy Policy") {
            showingLegalAgreement = true
        }
        .sheet(isPresented: $showingLegalAgreement) {
            LegalAgreementView(
                userId: authService.currentUser?.id ?? "",
                onAcceptance: {
                    showingLegalAgreement = false
                }
            )
        }
    }
}

#Preview {
    LegalAgreementManager()
        .environmentObject(AuthService())
}
