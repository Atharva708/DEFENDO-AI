//
//  Theme.swift
//  DEFENDO-AI
//
//  Centralized design tokens: colors, spacing, radii, typography helpers
//

import SwiftUI

struct Theme {
    struct Colors {
        static let brandPrimary = Color.accentColor
        static let brandSecondary = Color.blue
        static let surface = Color(.systemGray6)
        static let surfaceSecondary = Color(.secondarySystemBackground)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
    }

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
    }
}

// Generic card container for consistent surfaces
struct ThemedCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        content()
            .padding()
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Radius.md)
    }
}



