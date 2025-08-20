import SwiftUI

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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(locationService)
                .environmentObject(mapKitService)
                .environmentObject(notificationService)
                .environmentObject(emergencyContactService)
                .environmentObject(apiService)
                // Add other environment objects as needed
        }
    }
}
