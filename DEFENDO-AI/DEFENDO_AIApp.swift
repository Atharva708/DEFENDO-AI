//
//  DEFENDO_AIApp.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import Combine

@main
struct DEFENDO_AIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var locationService = LocationService()
    @StateObject private var emergencyContactService = EmergencyContactService()
    @StateObject private var apiService = APIService()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(notificationService)
                .environmentObject(locationService)
                .environmentObject(emergencyContactService)
                .environmentObject(apiService)
        }
    }
}

class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userRole: UserRole = .guest
    @Published var currentScreen: AppScreen = .onboarding
    
    enum UserRole {
        case user, provider, admin, guest
    }
    
    enum AppScreen {
        case onboarding, dashboard, sos, booking, marketplace, profile, providerDashboard, adminDashboard
    }
    
    // Mock data for the app
    init() {
        // Initialize with some mock data
        currentUser = User(
            id: "1",
            name: "John Doe",
            email: "john.doe@email.com",
            phone: "+1 (555) 123-4567",
            role: .user,
            safetyScore: 85,
            emergencyContacts: [
                EmergencyContact(id: "1", name: "Sarah Johnson", phone: "+1 (555) 987-6543", relationship: "Spouse"),
                EmergencyContact(id: "2", name: "Mike Smith", phone: "+1 (555) 456-7890", relationship: "Friend")
            ],
            bookings: [
                Booking(id: "1", serviceType: .securityGuard, provider: "Elite Security Services", date: Date().addingTimeInterval(86400), duration: 4, location: "Downtown Office", status: .confirmed, price: 100.0),
                Booking(id: "2", serviceType: .dronePatrol, provider: "SkyWatch Drones", date: Date().addingTimeInterval(-86400), duration: 2, location: "Residential Area", status: .completed, price: 70.0)
            ]
        )
    }
}

struct User {
    let id: String
    let name: String
    let email: String
    let phone: String
    let role: AppState.UserRole
    var safetyScore: Int = 85
    var emergencyContacts: [EmergencyContact] = []
    var bookings: [Booking] = []
}

struct EmergencyContact: Codable {
    let id: String
    let name: String
    let phone: String
    let relationship: String
}

struct Booking: Codable {
    let id: String
    let serviceType: ServiceType
    let provider: String
    let date: Date
    let duration: Int
    let location: String
    let status: BookingStatus
    let price: Double
}

// Codable conformance for JSON support
enum ServiceType: String, Codable {
    case securityGuard = "securityGuard"
    case dronePatrol = "dronePatrol"
}

// Codable conformance for JSON support
enum BookingStatus: String, Codable {
    case pending = "pending"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
}

// Additional models for the app
struct SOSAlert {
    let id: String
    let userId: String
    let location: String
    let timestamp: Date
    let status: SOSStatus
    let description: String?
}

// Codable conformance for JSON support
enum SOSStatus: String, Codable {
    case active = "active"
    case resolved = "resolved"
    case cancelled = "cancelled"
}

struct SafetyZone {
    let id: String
    let name: String
    let color: SafetyColor
    let riskLevel: Int
    let description: String
}

// Codable conformance for JSON support
enum SafetyColor: String, Codable {
    case green = "green"
    case yellow = "yellow"
    case red = "red"
}

// Provider domain models for marketplace are defined in `MarketplaceView.swift`

// Chat and messaging models
struct ChatMessage {
    let id: String
    let senderId: String
    let receiverId: String
    let message: String
    let timestamp: Date
    let messageType: MessageType
}

// Codable conformance for JSON support
enum MessageType: String, Codable {
    case text = "text"
    case image = "image"
    case location = "location"
    case sos = "sos"
}

// Analytics and reporting models
struct AnalyticsData {
    let bookingsCount: Int
    let revenue: Double
    let averageRating: Double
    let responseTime: Double
    let completionRate: Double
}

struct IncidentReport {
    let id: String
    let reporterId: String
    let incidentType: IncidentType
    let description: String
    let location: String
    let timestamp: Date
    let status: ReportStatus
    let attachments: [String] // URLs to images/videos
}

// Codable conformance for JSON support
enum IncidentType: String, Codable {
    case assault = "assault"
    case theft = "theft"
    case medical = "medical"
    case suspicious = "suspicious"
    case other = "other"
}

// Codable conformance for JSON support
enum ReportStatus: String, Codable {
    case pending = "pending"
    case investigating = "investigating"
    case resolved = "resolved"
    case dismissed = "dismissed"
}
