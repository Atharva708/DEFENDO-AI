//
//  CommunityView.swift
//  DEFENDO-AI
//
//  Main Community tab view with navigation
//

import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var communityService = CommunityService.shared
    @State private var community: Community?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let community = community {
                CommunityOverviewView()
                    .environmentObject(authService)
            } else {
                NoCommunityView()
            }
        }
        .task {
            await loadUserCommunity()
        }
    }
    
    private func loadUserCommunity() async {
        guard let userId = authService.currentUser?.id,
              let userUUID = UUID(uuidString: userId) else {
            isLoading = false
            return
        }
        
        do {
            community = try await communityService.fetchCommunity(for: userUUID)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(AuthService())
}
