//
//  Components.swift
//  DEFENDO-AI
//
//  Shared UI components: button styles, state views, haptics
//

import SwiftUI

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


