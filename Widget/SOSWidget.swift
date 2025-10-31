// SOSWidget.swift
// WidgetExtension
//
// Created for DEFENDO-AI by Assistant, 06/09/25.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Definition
struct SOSWidget: Widget {
    let kind: String = "SOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SOSProvider()) { entry in
            SOSWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Emergency SOS")
        .description("Quickly trigger SOS from your Home or Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View
struct SOSWidgetView: View {
    let entry: SOSWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Improved vibrant background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.85, green: 0.07, blue: 0.2), Color(red: 0.25, green: 0, blue: 0)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Visual SOS button (non-interactive - entire widget triggers app)
            ZStack {
                // Button background shape with inner and outer glows
                (family == .systemSmall ?
                    AnyView(
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.35), lineWidth: 6)
                                        .blur(radius: 2)
                                )
                                .background(
                                    Circle().fill(.ultraThinMaterial)
                                )
                                .shadow(color: Color.red.opacity(0.36), radius: 13, x: 0, y: 4)
                            Text("SOS")
                                .font(.system(size: 24, weight: .heavy, design: .default))
                                .foregroundStyle(.white)
                                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                        }
                        .frame(width: 100, height: 100)
                    ) :
                    AnyView(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color.red)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 12)
                                    .blur(radius: 14)
                                    .opacity(0.8)
                            )
                            .shadow(color: Color.red.opacity(0.7), radius: 20, x: 0, y: 0)
                            .shadow(color: Color.white.opacity(0.12), radius: 6, x: 0, y: 0)
                    )
                )

                // SOS Text
                if family != .systemSmall {
                    Text("SOS")
                        .font(.system(size: 24, weight: .heavy, design: .default))
                        .foregroundStyle(.white)
                        .shadow(color: Color.red.opacity(0.85), radius: 4, x: 0, y: 0)
                        .shadow(color: Color.white.opacity(0.45), radius: 2, x: 0, y: 0)
                }
            }
            .frame(width: family == .systemSmall ? 112 : 180, height: family == .systemSmall ? 112 : 70)
            .contentShape(family == .systemSmall ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 20)))
            // Note: The entire widget is tappable via the widgetURL below; this view is now static.
        }
        // The entire widget triggers the app via this URL when tapped.
        .widgetURL(URL(string: "defendoai://sos"))
    }
}

// Helper for conditional modifiers
extension View {
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Timeline Entry
struct SOSWidgetEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider
struct SOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> SOSWidgetEntry {
        SOSWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SOSWidgetEntry) -> Void) {
        completion(SOSWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SOSWidgetEntry>) -> Void) {
        let entries = [SOSWidgetEntry(date: Date())]
        completion(Timeline(entries: entries, policy: .never))
    }
}

// MARK: - AppIntent for SOS
struct TriggerSOSIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger SOS"

    // Provide a parameter summary, even if no parameters are needed
    static var parameterSummary: some ParameterSummary {
        Summary("Trigger the SOS action")
    }

    // This opens the app to the SOS deep link. Handle "defendoai://sos" in your app (e.g., via onOpenURL) to trigger the actual SOS logic.
    func perform() async throws -> some IntentResult {
        // Open the app with a custom SOS URL; app must handle this deep link to trigger SOS
        let url = URL(string: "defendoai://sos")
        return .result(value: url)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    SOSWidgetView(entry: SOSWidgetEntry(date: Date()))
}
#endif
