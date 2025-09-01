//
//  SupabaseService.swift
//  DEFENDO-AI
//
//  Real Supabase integration with proper data models
//

import Foundation
import Supabase
import Combine

// MARK: - Shared Date Formatters

enum DateFormats {
    /// 2025-09-01T12:34:56.789Z (UTC, RFC3339)
    static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// 24h time "HH:mm:ss" (POSIX, UTC)
    static let timeHMS: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Calendar date "yyyy-MM-dd" (POSIX, UTC)
    static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - User Profiles

    func createUserProfile(_ user: User) async throws {
        let now = DateFormats.rfc3339.string(from: Date())
        let profile = UserProfileInsert(
            id: user.id,
            email: user.email,
            full_name: user.name,
            phone: user.phone,
            role: user.role.rawValue,
            safety_score: user.safetyScore,
            created_at: now,
            updated_at: now
        )

        _ = try await client
            .from("users")
            .insert(profile)
            .execute()
    }

    func updateUserProfile(_ user: User) async throws {
        let updates = UserProfileUpdate(
            full_name: user.name,
            phone: user.phone,
            updated_at: DateFormats.rfc3339.string(from: Date())
        )

        _ = try await client
            .from("users")
            .update(updates)
            .eq("id", value: user.id)
            .execute()
    }

    func getUserProfile(id: String) async throws -> User? {
        let response: PostgrestResponse<UserProfileRow> = try await client
            .from("users")
            .select()
            .eq("id", value: id)
            .single()
            .execute()

        let profile = response.value

        return User(
            id: profile.id,
            name: profile.full_name ?? "User",
            email: profile.email ?? "",
            phone: profile.phone ?? "",
            role: UserRole(rawValue: profile.role ?? "user") ?? .user,
            safetyScore: profile.safety_score ?? 85
        )
    }

    // MARK: - Emergency Contacts

    func saveEmergencyContacts(_ contacts: [EmergencyContact], userId: String) async throws {
        _ = try await client
            .from("emergency_contacts")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        let now = DateFormats.rfc3339.string(from: Date())
        let contactData = contacts.map { contact in
            EmergencyContactInsert(
                id: contact.id,
                user_id: userId,
                name: contact.name,
                phone: contact.phone,
                relationship: contact.relationship,
                is_primary: contact.isPrimary,
                created_at: now,
                updated_at: now
            )
        }

        if !contactData.isEmpty {
            _ = try await client
                .from("emergency_contacts")
                .insert(contactData)
                .execute()
        }
    }

    func getEmergencyContacts(userId: String) async throws -> [EmergencyContact] {
        let response: PostgrestResponse<[EmergencyContactRecord]> = try await client
            .from("emergency_contacts")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()

        return response.value.map { row in
            EmergencyContact(
                id: row.id,
                name: row.name,
                phone: row.phone,
                relationship: row.relationship ?? "Contact",
                isPrimary: row.is_primary ?? false
            )
        }
    }

    // MARK: - SOS Alerts

    func createSOSAlert(_ alert: SOSAlertData) async throws -> String {
        let now = DateFormats.rfc3339.string(from: Date())
        let deviceInfoData = try JSONEncoder().encode(alert.deviceInfo)
        let deviceInfoString = String(data: deviceInfoData, encoding: .utf8) ?? "{}"

        let alertData = SOSAlertInsert(
            id: alert.id,
            user_id: alert.userId,
            status: alert.status.rawValue,
            latitude: alert.latitude,
            longitude: alert.longitude,
            address: alert.address,
            description: alert.description,
            device_info: deviceInfoString,
            created_at: now,
            police_notified: false,
            emergency_contacts_notified: false,
            location_accuracy: alert.locationAccuracy,
            battery_level: alert.batteryLevel,
            signal_strength: alert.signalStrength
        )

        _ = try await client
            .from("sos_alerts")
            .insert(alertData)
            .execute()

        return alert.id
    }

    func updateSOSAlert(id: String, status: SOSStatus) async throws {
        let resolvedAt: String? = (status == .resolved || status == .cancelled)
            ? DateFormats.rfc3339.string(from: Date())
            : nil

        let updatePayload = SOSAlertUpdate(
            status: status.rawValue,
            updated_at: DateFormats.rfc3339.string(from: Date()),
            resolved_at: resolvedAt
        )

        _ = try await client
            .from("sos_alerts")
            .update(updatePayload)
            .eq("id", value: id)
            .execute()
    }

    func getSOSAlerts(userId: String) async throws -> [SOSAlertData] {
        let response: PostgrestResponse<[SOSAlertRow]> = try await client
            .from("sos_alerts")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()

        return try response.value.map { row in
            let deviceInfo: DeviceInfo
            if let deviceInfoString = row.device_info,
               let jsonData = deviceInfoString.data(using: .utf8) {
                deviceInfo = try JSONDecoder().decode(DeviceInfo.self, from: jsonData)
            } else {
                deviceInfo = DeviceInfo(platform: "iOS", version: "Unknown", model: "Unknown", appVersion: "1.0")
            }

            return SOSAlertData(
                id: row.id,
                userId: row.user_id,
                status: SOSStatus(rawValue: row.status) ?? .active,
                latitude: row.latitude,
                longitude: row.longitude,
                address: row.address,
                description: row.description,
                deviceInfo: deviceInfo,
                locationAccuracy: row.location_accuracy,
                batteryLevel: row.battery_level,
                signalStrength: row.signal_strength
            )
        }
    }

    // MARK: - Bookings

    func createBooking(_ booking: BookingData) async throws -> String {
        let now = DateFormats.rfc3339.string(from: Date())
        let bookingData = BookingInsert(
            id: booking.id,
            user_id: booking.userId,
            provider_id: booking.providerId,
            service_type: booking.serviceType.rawValue,
            booking_date: DateFormats.ymd.string(from: booking.date),
            start_time: DateFormats.timeHMS.string(from: booking.startTime),
            end_time: DateFormats.timeHMS.string(from: booking.endTime),
            duration_hours: booking.durationHours,
            location: booking.location,
            latitude: booking.latitude,
            longitude: booking.longitude,
            status: booking.status.rawValue,
            price: booking.price,
            payment_status: "pending",
            created_at: now,
            updated_at: now,
            user_notes: booking.userNotes
        )

        _ = try await client
            .from("bookings")
            .insert(bookingData)
            .execute()

        return booking.id
    }

    func getBookings(userId: String) async throws -> [BookingData] {
        let response: PostgrestResponse<[BookingRow]> = try await client
            .from("bookings")
            .select()
            .eq("user_id", value: userId)
            .order("booking_date", ascending: false)
            .order("start_time", ascending: false)
            .execute()

        return response.value.compactMap { row in
            guard
                let date = DateFormats.ymd.date(from: row.booking_date),
                let startTime = DateFormats.timeHMS.date(from: row.start_time),
                let endTime = DateFormats.timeHMS.date(from: row.end_time)
            else {
                return nil
            }

            return BookingData(
                id: row.id,
                userId: row.user_id,
                providerId: row.provider_id,
                serviceType: ServiceType(rawValue: row.service_type) ?? .securityGuard,
                date: date,
                startTime: startTime,
                endTime: endTime,
                durationHours: row.duration_hours,
                location: row.location,
                latitude: row.latitude,
                longitude: row.longitude,
                status: BookingStatus(rawValue: row.status) ?? .pending,
                price: row.price,
                userNotes: row.user_notes
            )
        }
    }

    // MARK: - Location History

    func saveLocationHistory(userId: String, location: LocationHistoryData) async throws {
        let locationData = LocationHistoryInsert(
            id: UUID().uuidString,
            user_id: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.accuracy,
            speed: location.speed,
            heading: location.heading,
            altitude: location.altitude,
            timestamp: DateFormats.rfc3339.string(from: location.timestamp),
            address: location.address,
            safety_score: location.safetyScore
        )

        _ = try await client
            .from("location_history")
            .insert(locationData)
            .execute()
    }

    // MARK: - Real-time Subscriptions

    func subscribeToSOSAlerts() -> AnyPublisher<SOSAlertData, Error> {
        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - Data Models for Supabase (Rows)

nonisolated(unsafe) struct UserProfileRow: Codable, Sendable {
    let id: String
    let email: String?
    let full_name: String?
    let phone: String?
    let role: String?
    let safety_score: Int?
    let created_at: String
    let updated_at: String
}

nonisolated(unsafe) struct EmergencyContactRecord: Codable, Sendable {
    let id: String
    let user_id: String
    let name: String
    let phone: String
    let relationship: String?
    let is_primary: Bool?
    let created_at: String
    let updated_at: String
}

nonisolated(unsafe) struct SOSAlertRow: Codable, Sendable {
    let id: String
    let user_id: String
    let status: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let description: String?
    let device_info: String?
    let created_at: String
    let resolved_at: String?
    let police_notified: Bool?
    let emergency_contacts_notified: Bool?
    let location_accuracy: Double?
    let battery_level: Int?
    let signal_strength: Int?
}

nonisolated(unsafe) struct BookingRow: Codable, Sendable {
    let id: String
    let user_id: String
    let provider_id: String
    let service_type: String
    let booking_date: String
    let start_time: String
    let end_time: String
    let duration_hours: Int
    let location: String
    let latitude: Double?
    let longitude: Double?
    let status: String
    let price: Double
    let payment_status: String
    let created_at: String
    let updated_at: String
    let user_notes: String?
}

// MARK: - Insert/Update Helper Payloads

nonisolated(unsafe) struct UserProfileInsert: Codable, Sendable {
    let id: String
    let email: String
    let full_name: String
    let phone: String
    let role: String
    let safety_score: Int
    let created_at: String
    let updated_at: String
}

nonisolated(unsafe) struct UserProfileUpdate: Codable, Sendable {
    let full_name: String
    let phone: String
    let updated_at: String
}

nonisolated(unsafe) struct EmergencyContactInsert: Codable, Sendable {
    let id: String
    let user_id: String
    let name: String
    let phone: String
    let relationship: String?
    let is_primary: Bool
    let created_at: String
    let updated_at: String
}

nonisolated(unsafe) struct SOSAlertInsert: Codable, Sendable {
    let id: String
    let user_id: String
    let status: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let description: String?
    let device_info: String
    let created_at: String
    let police_notified: Bool
    let emergency_contacts_notified: Bool
    let location_accuracy: Double?
    let battery_level: Int?
    let signal_strength: Int?
}

nonisolated(unsafe) struct SOSAlertUpdate: Codable, Sendable {
    let status: String
    let updated_at: String
    let resolved_at: String?
}

nonisolated(unsafe) struct BookingInsert: Codable, Sendable {
    let id: String
    let user_id: String
    let provider_id: String
    let service_type: String
    let booking_date: String
    let start_time: String
    let end_time: String
    let duration_hours: Int
    let location: String
    let latitude: Double?
    let longitude: Double?
    let status: String
    let price: Double
    let payment_status: String
    let created_at: String
    let updated_at: String
    let user_notes: String?
}

nonisolated(unsafe) struct LocationHistoryInsert: Codable, Sendable {
    let id: String
    let user_id: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let speed: Double?
    let heading: Double?
    let altitude: Double?
    let timestamp: String
    let address: String?
    let safety_score: Int?
}

// MARK: - App Data Models

struct SOSAlertData: Sendable {
    let id: String
    let userId: String
    let status: SOSStatus
    let latitude: Double
    let longitude: Double
    let address: String?
    let description: String?
    let deviceInfo: DeviceInfo
    let locationAccuracy: Double?
    let batteryLevel: Int?
    let signalStrength: Int?
}

struct BookingData: Sendable {
    let id: String
    let userId: String
    let providerId: String
    let serviceType: ServiceType
    let date: Date
    let startTime: Date
    let endTime: Date
    let durationHours: Int
    let location: String
    let latitude: Double?
    let longitude: Double?
    let status: BookingStatus
    let price: Double
    let userNotes: String?
}

struct LocationHistoryData: Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let speed: Double?
    let heading: Double?
    let altitude: Double?
    let timestamp: Date
    let address: String?
    let safetyScore: Int?
}

// MARK: - Helper Extensions

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
