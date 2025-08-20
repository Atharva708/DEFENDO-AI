//
//  SharedTypes.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import Foundation
import UIKit
import CoreLocation
import Combine

// MARK: - Screen Navigation
enum Screen: String, CaseIterable, Codable, Sendable {
    case dashboard = "dashboard"
    case sos = "sos"
    case booking = "booking"
    case profile = "profile"
    case marketplace = "marketplace"
    case admin = "admin"
    case provider = "provider"
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentScreen: Screen = .dashboard
    @Published var userRole: UserRole = .user
    
    init() {
        // Initialize with default values
    }
}

// MARK: - User Role
enum UserRole: String, CaseIterable, Sendable, Codable {
    case user = "user"
    case provider = "provider"
    case admin = "admin"
    case guest = "guest"
}

// MARK: - User Model
struct User: Identifiable, Codable, Sendable {
    let id: String
    var name: String
    let email: String
    var phone: String
    let role: UserRole
    let safetyScore: Int
    
    init(id: String, name: String, email: String, phone: String, role: UserRole, safetyScore: Int) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.role = role
        self.safetyScore = safetyScore
    }
}

// MARK: - SOS Status
enum SOSStatus: String, CaseIterable, Codable, Sendable {
    case active = "active"
    case resolved = "resolved"
    case cancelled = "cancelled"
    case pending = "pending"
}

// MARK: - Safety Zone
struct SafetyZone: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let color: SafetyZoneColor
    let riskLevel: Int
    let description: String
    
    init(id: String, name: String, color: SafetyZoneColor, riskLevel: Int, description: String) {
        self.id = id
        self.name = name
        self.color = color
        self.riskLevel = riskLevel
        self.description = description
    }
}

enum SafetyZoneColor: String, CaseIterable, Codable, Sendable {
    case green = "green"
    case yellow = "yellow"
    case red = "red"
    
    var uiColor: UIColor {
        switch self {
        case .green:
            return .systemGreen
        case .yellow:
            return .systemOrange
        case .red:
            return .systemRed
        }
    }
}

// MARK: - Incident Types
enum IncidentType: String, CaseIterable, Codable, Sendable {
    case suspicious = "suspicious"
    case theft = "theft"
    case assault = "assault"
    case vandalism = "vandalism"
    case harassment = "harassment"
    case fire = "fire"
    case medical = "medical"
    case other = "other"
}

enum IncidentStatus: String, CaseIterable, Codable, Sendable {
    case reported = "reported"
    case investigating = "investigating"
    case resolved = "resolved"
    case closed = "closed"
}

// MARK: - Incident Report
struct IncidentReport: Identifiable, Codable, Sendable {
    let id: String
    let reporterId: String
    let incidentType: IncidentType
    let description: String
    let location: String
    let timestamp: Date
    let status: IncidentStatus
    let attachments: [String] // URLs to attachments
    
    init(id: String, reporterId: String, incidentType: IncidentType, description: String, location: String, timestamp: Date, status: IncidentStatus, attachments: [String]) {
        self.id = id
        self.reporterId = reporterId
        self.incidentType = incidentType
        self.description = description
        self.location = location
        self.timestamp = timestamp
        self.status = status
        self.attachments = attachments
    }
}

// MARK: - Service Types
enum ServiceType: String, CaseIterable, Codable, Sendable {
    case securityGuard = "securityGuard"
    case dronePatrol = "dronePatrol"
    case surveillance = "surveillance"
    case escort = "escort"
    case emergency = "emergency"
}

enum BookingStatus: String, CaseIterable, Codable, Sendable {
    case pending = "pending"
    case confirmed = "confirmed"
    case inProgress = "inProgress"
    case completed = "completed"
    case cancelled = "cancelled"
}

// MARK: - Booking
struct Booking: Identifiable, Codable, Sendable {
    let id: String
    let serviceType: ServiceType
    let provider: String
    let date: Date
    let duration: Int // in hours
    let location: String
    let status: BookingStatus
    let price: Double
    
    init(id: String, serviceType: ServiceType, provider: String, date: Date, duration: Int, location: String, status: BookingStatus, price: Double) {
        self.id = id
        self.serviceType = serviceType
        self.provider = provider
        self.date = date
        self.duration = duration
        self.location = location
        self.status = status
        self.price = price
    }
}

// MARK: - Emergency Contact
struct EmergencyContact: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let phone: String
    let relationship: String
    let isPrimary: Bool
    
    init(id: String, name: String, phone: String, relationship: String, isPrimary: Bool = false) {
        self.id = id
        self.name = name
        self.phone = phone
        self.relationship = relationship
        self.isPrimary = isPrimary
    }
}

// MARK: - Severity Levels
enum SeverityLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - Extensions
extension SeverityLevel {
    var color: UIColor {
        switch self {
        case .low:
            return .systemGreen
        case .medium:
            return .systemOrange
        case .high:
            return .systemRed
        case .critical:
            return .systemPurple
        }
    }
}
