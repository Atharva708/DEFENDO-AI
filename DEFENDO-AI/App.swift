import SwiftUI
import UIKit

@main
struct DEFENDO_AIApp: App {
    // Instantiate your shared services and state objects here
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()
    @StateObject private var locationService = LocationService()
    @StateObject private var mapKitService = MapKitService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var emergencyContactService = EmergencyContactService()
    @StateObject private var apiService = APIService()
    // Add other services as needed

    private let supabaseURL = AppConfig.Supabase.url
    private let supabaseAnon = AppConfig.Supabase.anonKey

    @State private var triggerSOSFromDeepLink = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // Ensure Supabase is configured at runtime
                    if !supabaseURL.isEmpty && !supabaseAnon.isEmpty {
                        SupabaseManager.shared.configure(url: supabaseURL, key: supabaseAnon)
                        _ = SupabaseManager.shared.client // force initialize
                    } else {
                        print("[Supabase] Missing URL/Anon Key. Set Info.plist SUPABASE_URL_* and SUPABASE_ANON_KEY_* or call configure(url:key:)")
                    }
                }
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(locationService)
                .environmentObject(mapKitService)
                .environmentObject(notificationService)
                .environmentObject(emergencyContactService)
                .environmentObject(apiService)
                .fullScreenCover(isPresented: $triggerSOSFromDeepLink, content: {
                    SOSView()
                        .environmentObject(appState)
                        .environmentObject(authService)
                        .environmentObject(notificationService)
                        .environmentObject(locationService)
                        .environmentObject(emergencyContactService)
                        .environmentObject(apiService)
                        .onAppear {
                            // Trigger SOS only when launched from deep link
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(name: NSNotification.Name("TriggerSOSFromWidget"), object: nil)
                            }
                        }
                })
                .onOpenURL { url in
                    if url.scheme == "defendoai" && url.host == "sos" {
                        triggerSOSFromDeepLink = true
                    }
                }
        }
    }
}
