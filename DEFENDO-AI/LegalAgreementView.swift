//
//  LegalAgreementView.swift
//  DEFENDO-AI
//
//  Terms and Conditions and Privacy Policy agreement view
//

import SwiftUI

struct LegalAgreementView: View {
    // Use the shared service directly (avoid potential dynamicMember / wrapper confusion)
    private let supabaseService = SupabaseService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentTab: LegalTab = .terms
    @State private var isAccepting = false
    @State private var errorMessage: String?

    let userId: String
    let onAcceptance: () -> Void

    enum LegalTab: CaseIterable {
        case terms, privacy

        var title: String {
            switch self {
            case .terms: return "Terms & Conditions"
            case .privacy: return "Privacy Policy"
            }
        }

        var content: String {
            switch self {
            case .terms: return LegalContent.termsAndConditions
            case .privacy: return LegalContent.privacyPolicy
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView

                // Tab Selector
                tabSelector

                // Content
                contentView

                // Accept Button
                acceptButton
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)

                Spacer()

                Text("Legal Agreement")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Invisible button for balance
                Button("Cancel") {
                    dismiss()
                }
                .opacity(0)
            }
            .padding(.horizontal)

            Text("Please read and accept our Terms & Conditions and Privacy Policy to continue using DEFENDO-AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(LegalTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Rectangle()
                            .fill(currentTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .foregroundColor(currentTab == tab ? .blue : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }

    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(currentTab.content)
                    .font(.body)
                    .lineSpacing(4)
                    .padding()
                
                // Bottom anchor
                Color.clear
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Accept Button
    private var acceptButton: some View {
        VStack(spacing: 12) {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: acceptLegalAgreement) {
                HStack {
                    if isAccepting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }

                    Text("I Understand & Accept")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isAccepting)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Helper Methods
    private func acceptLegalAgreement() {
        isAccepting = true
        errorMessage = nil

        Task {
            do {
                print("[Legal] Recording acceptance for user: \(userId)")
                // Call the Supabase service directly
                try await supabaseService.recordLegalAcceptance(
                    userId: userId,
                    termsAccepted: true,
                    privacyPolicyAccepted: true
                )
                
                print("[Legal] Successfully recorded acceptance")
            } catch {
                print("[Legal] Error recording acceptance: \(error)")
                // Still proceed even if recording fails - this is non-critical
            }
            
            // Always proceed to homepage
            await MainActor.run {
                isAccepting = false
                onAcceptance()
                dismiss()
            }
        }
    }
}

#Preview {
    LegalAgreementView(
        userId: "test-user-id",
        onAcceptance: {}
    )
}
