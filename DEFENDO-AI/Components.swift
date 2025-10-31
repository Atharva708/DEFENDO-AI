//
//  Components.swift
//  DEFENDO-AI
//
//  Shared UI components: button styles, state views, haptics
//

import SwiftUI
import Combine
import Supabase

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Theme.Colors.brandPrimary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Theme.Colors.surface)
            .foregroundColor(Theme.Colors.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Theme.Colors.brandPrimary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Haptics
enum Haptics {
    static func success() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - State Views
struct LoadingStateView: View {
    let title: String
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
            Text(title).font(.headline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryTitle: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button(retryTitle, action: onRetry).buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "tray").font(.largeTitle).foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action).buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Skeletons
struct BookingSkeletonCard: View {
    var body: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.3)).frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.25)).frame(width: 120, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.25)).frame(width: 60, height: 18)
                }
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.25)).frame(height: 10)
                }
                HStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(width: 90, height: 32)
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(width: 120, height: 32)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

struct ServiceSkeletonCard: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.25)).frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 160, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.25)).frame(width: 80, height: 10)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(width: 120, height: 10)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.Colors.surfaceSecondary)
        )
        .redacted(reason: .placeholder)
    }
}

// MARK: - Pre-permission Explainer
struct PrePermissionView: View {
    let title: String
    let message: String
    let bulletPoints: [String]
    let continueTitle: String
    let onContinue: () -> Void
    let onNotNow: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(title).font(.title2).fontWeight(.bold)
                Text(message).font(.body).foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(bulletPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(point).font(.subheadline)
                        }
                    }
                }
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    Button(continueTitle) { onContinue() }.buttonStyle(PrimaryButtonStyle())
                    Button("Not now") { onNotNow() }.buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Toolbar Style
struct DefaultToolbarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func applyDefaultToolbar() -> some View { self.modifier(DefaultToolbarStyle()) }
}

// The following button styles already exist, so do not add duplicates.
// The following View extension applyDefaultToolbar() already exists, so do not add duplicates.

// MARK: - PhoneOTPLoginView
struct PhoneOTPLoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var phoneNumber: String = ""
    @State private var otpCode: String = ""
    @State private var isRequesting: Bool = false
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String?
    @State private var didSendCode: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        Text("Sign in with Phone")
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                    }

                    // Card
                    VStack(spacing: 18) {
                        Group {
                            HStack {
                                Text("Phone Number")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.systemGray6))
                                HStack(spacing: 12) {
                                    Text("+")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 14)
                                    TextField("1 555 123 4567", text: $phoneNumber)
                                        .textContentType(.telephoneNumber)
                                        .keyboardType(.phonePad)
                                        .font(.title3)
                                        .padding(.vertical, 14)
                                }
                            }
                            .frame(height: 56)
                        }

                        if didSendCode {
                            Group {
                                HStack {
                                    Text("Enter OTP")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(.systemGray6))
                                    TextField("6-digit code", text: $otpCode)
                                        .textContentType(.oneTimeCode)
                                        .keyboardType(.numberPad)
                                        .font(.title3.monospacedDigit())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                }
                                .frame(height: 56)
                            }
                        }

                        if let errorMessage = errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        Text("Enter your mobile number")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()
                            .background(Color(.systemGray4))

                        if !didSendCode {
                            Button(action: requestCode) {
                                HStack { if isRequesting { ProgressView().tint(.white) } ; Text("Send OTP").bold() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(height: 52)
                            .disabled(isRequesting || !isValidPhone(phoneNumber))

                            Text("We’ll never share your number. Standard SMS charges may apply.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Button(action: verifyCode) {
                                HStack { if isVerifying { ProgressView().tint(.white) } ; Text("Verify & Continue").bold() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(height: 52)
                            .disabled(isVerifying || otpCode.count < 4)

                            Button("Resend Code", action: requestCode)
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(isRequesting)

                            Text("We’ll never share your number. Standard SMS charges may apply.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemBackground)))
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .padding(.horizontal)

                    Spacer(minLength: 10)
                }
                .padding()
            }
            .navigationTitle("Sign in with Phone")
        }
    }

    private func requestCode() {
        errorMessage = nil
        isRequesting = true
        Task {
            do {
                guard let e164 = formattedE164Phone else { throw NSError(domain: "Phone", code: 0, userInfo: [NSLocalizedDescriptionKey: "Enter a valid phone number"]) }
                try await authService.requestOTP(phone: e164)
                didSendCode = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isRequesting = false
        }
    }

    private func verifyCode() {
        errorMessage = nil
        isVerifying = true
        Task {
            do {
                guard let e164 = formattedE164Phone else { throw NSError(domain: "Phone", code: 0, userInfo: [NSLocalizedDescriptionKey: "Enter a valid phone number"]) }
                try await authService.verifyOTP(phone: e164, code: otpCode)
            } catch {
                errorMessage = error.localizedDescription
            }
            isVerifying = false
        }
    }

    private func isValidPhone(_ value: String) -> Bool {
        // Accept international phone numbers
        let cleaned = value.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return cleaned.count >= 10 && cleaned.count <= 15
    }
    
    private var formattedE164Phone: String? {
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        // If it already starts with +, return as is
        if cleaned.hasPrefix("+") {
            return cleaned.count >= 10 ? cleaned : nil
        }
        
        // If it's a 10-digit number, assume it's Indian and add +91
        let digits = cleaned.filter { $0.isNumber }
        if digits.count == 10 {
            return "+91" + digits
        }
        
        // For other cases, try to format as international
        if digits.count >= 10 && digits.count <= 15 {
            return "+" + digits
        }
        
        return nil
    }
}

protocol PhoneOTPAuthenticating {
    func requestOTP(phone: String) async throws
    func verifyOTP(phone: String, code: String) async throws
}

extension AuthService: PhoneOTPAuthenticating {
    @MainActor
    func requestOTP(phone: String) async throws {
        // Use SupabaseService for OTP functionality
        try await SupabaseService.shared.startOTP(for: phone)
    }

    @MainActor
    func verifyOTP(phone: String, code: String) async throws {
        // Use SupabaseService for OTP verification
        if let userId = try await SupabaseService.shared.verifyOTP(phoneNumber: phone, code: code) {
            // Check if user has accepted legal terms
            let hasAcceptedLegal = try await SupabaseService.shared.hasUserAcceptedLegal(userId: userId)
            
            // Update AuthService state
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = User(
                    id: userId,
                    name: phone, // Use phone as display name initially
                    email: "",
                    phone: phone,
                    role: .user,
                    safetyScore: 85
                )
                self.authSuccess = "Successfully signed in!"
                
                // Store legal acceptance status
                UserDefaults.standard.set(hasAcceptedLegal, forKey: "user_legal_accepted_\(userId)")
            }
        } else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "OTP verification failed"])
        }
    }
    
    // MARK: - Legal Acceptance Management
    
    /// Check if current user has accepted legal terms
    func hasCurrentUserAcceptedLegal() -> Bool {
        guard let userId = currentUser?.id else { return false }
        return UserDefaults.standard.bool(forKey: "user_legal_accepted_\(userId)")
    }
    
    /// Record legal acceptance for current user
    func recordLegalAcceptance() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            try await SupabaseService.shared.recordLegalAcceptance(
                userId: userId,
                termsAccepted: true,
                privacyPolicyAccepted: true
            )
            
            await MainActor.run {
                UserDefaults.standard.set(true, forKey: "user_legal_accepted_\(userId)")
            }
        } catch {
            print("[AuthService] Failed to record legal acceptance: \(error)")
        }
    }
}

// Helper to set isAuthenticated reflectively without knowing exact storage, stays no-op if not provided.
private enum AuthServiceBooleanKeyPaths {
    // If your AuthService defines `@Published var isAuthenticated: Bool`, set its key path here to enable auto-login after OTP.
    static var isAuthenticated: ReferenceWritableKeyPath<AuthService, Bool>? { \AuthService.isAuthenticated }
}

// NOTE: Remove Terms/Privacy gating in RootView by deleting fullScreenCovers and checks.

