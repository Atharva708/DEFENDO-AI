//
//  SupabaseService.swift
//  DEFENDO-AI
//
//  Real Supabase integration with proper data models
//
//  See SupabaseNetworkHelper.swift for REST booking POSTs and file loader.
//

import Foundation
import Supabase
import Combine
import UIKit

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

/*
 MARK: - Booking DB Constraints & Field Requirements

 - user_id, provider_id: Optional UUID strings; must be valid UUIDs if present.
 - service_type: Required; must match one of the DB enum values (e.g., "security_guard", "patrol", "guard").
   Convert from app ServiceType enum to lowercase underscore-separated strings.
 - booking_date: Required; formatted as "yyyy-MM-dd".
 - start_time, end_time: Required; formatted as "HH:mm:ss".
 - duration_hours: Required; Int representing total duration in hours.
 - location: Required; non-empty string.
 - status: Required; one of ["pending", "confirmed", "in_progress", "completed", "cancelled"].
 - price: Required; positive Double.
 - payment_status: Required; one of ["pending", "paid", "refunded", "failed"] etc.
 - created_at, updated_at: Required; RFC3339 formatted datetime strings.
 - Legacy fields `date` and `duration` are no longer present in DB schema and must be removed.
 - Optional fields (currency, payment_method, transaction_id, refund_id, host_payout_status, payout_date) are nullable.
 
 Validation is critical as inserting invalid enum values or missing required fields will cause DB constraint violations.
 Logging detailed errors on failures helps debugging.
*/

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

    /// Creates a new booking.
    /// Note: To avoid blocking the main thread, yields control to the scheduler first.
    /// - Parameter booking: BookingData to save.
    /// - Returns: The booking ID on success.
    /// If using REST API directly, see SupabaseREST.postBooking in SupabaseNetworkHelper.swift.
    func createBooking(_ booking: BookingData) async throws -> String {
        // Yield control to avoid blocking the main thread
        await Task.yield()

        // Validate and sanitize inputs for DB constraints before creating insert object
        guard !booking.id.isEmpty else {
            throw NSError(domain: "BookingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Booking id must not be empty"])
        }

        // user_id and provider_id are optional but if present must be valid UUID strings
        func isValidUUID(_ str: String) -> Bool {
            UUID(uuidString: str) != nil
        }

        let userIdOpt = booking.userId.isEmpty ? nil : (isValidUUID(booking.userId) ? booking.userId : nil)
        let providerIdOpt = booking.providerId.isEmpty ? nil : (isValidUUID(booking.providerId) ? booking.providerId : nil)

        // Normalize serviceType to match DB enum values:
        // Convert to lowercase and replace camelCase/enum conventions to underscore-separated.
        // Examples: "securityGuard" or "guard" -> "security_guard" or "guard"
        // Assuming ServiceType has a dbValue with appropriate format, else do conversion here.
        var serviceTypeDB = booking.serviceType.dbValue.lowercased()
        serviceTypeDB = serviceTypeDB.replacingOccurrences(of: " ", with: "_")
        serviceTypeDB = serviceTypeDB.replacingOccurrences(of: "-", with: "_")

        // Allowed service types per DB schema - Example set (adjust if needed)
        let allowedServiceTypes = ["bodyguard", "guard", "patrol", "cleaning", "delivery"]
        guard allowedServiceTypes.contains(serviceTypeDB) else {
            throw NSError(domain: "BookingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Booking service_type '\(serviceTypeDB)' is not allowed"])
        }

        // Validate status against allowed DB enum values
        let statusDB = booking.status.dbValue.lowercased()
        let allowedStatusValues = ["pending", "confirmed", "in_progress", "completed", "cancelled"]
        guard allowedStatusValues.contains(statusDB) else {
            throw NSError(domain: "BookingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Booking status '\(statusDB)' is not allowed"])
        }

        // Validate paymentStatus similarly, fallback to 'pending' if invalid
        var paymentStatusDB = booking.paymentStatus.lowercased()
        let allowedPaymentStatuses = ["pending", "paid", "refunded", "failed", "cancelled"]
        if !allowedPaymentStatuses.contains(paymentStatusDB) {
            paymentStatusDB = "pending"
        }

        // Validate location string non-empty
        guard !booking.location.isEmpty else {
            throw NSError(domain: "BookingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Booking location must not be empty"])
        }

        // Validate price - must be non-negative
        let priceFinal = booking.price.isNaN || booking.price < 0 ? 1.0 : booking.price

        // Validate date fields formatted correctly
        let bookingDateStr = DateFormats.ymd.string(from: booking.date)
        let startTimeStr = DateFormats.timeHMS.string(from: booking.startTime)
        let endTimeStr = DateFormats.timeHMS.string(from: booking.endTime)

        // Validate durationHours non-negative
        guard booking.durationHours >= 0 else {
            throw NSError(domain: "BookingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Booking durationHours must be zero or positive"])
        }

        // Timestamps for created_at and updated_at
        let now = DateFormats.rfc3339.string(from: Date())

        // Construct insert payload WITHOUT legacy fields `date` and `duration`
        let bookingData = BookingInsert(
            id: booking.id,
            user_id: userIdOpt,
            provider_id: providerIdOpt,
            service_type: serviceTypeDB,
            location: booking.location,
            status: statusDB,
            price: priceFinal,
            created_at: now,
            booking_date: bookingDateStr,
            start_time: startTimeStr,
            end_time: endTimeStr,
            duration_hours: booking.durationHours,
            latitude: booking.latitude,
            longitude: booking.longitude,
            payment_status: paymentStatusDB,
            updated_at: now,
            user_notes: booking.userNotes,
            currency: nil,
            payment_method: nil,
            transaction_id: nil,
            refund_id: nil,
            host_payout_status: nil,
            payout_date: nil
        )

        if AppConfig.Features.enableDetailedLogging {
            print("[Bookings] Attempting to insert booking: \(bookingData)")
        }

        do {
            _ = try await client
                .from("bookings")
                .insert(bookingData)
                .execute()
            if AppConfig.Features.enableDetailedLogging {
                print("[Bookings] SDK insert succeeded for id=\(booking.id)")
            }
        } catch {
            if AppConfig.Features.enableDetailedLogging {
                print("[Bookings] SDK insert failed with error: \(error)")
                print("[Bookings] Booking data causing error: \(bookingData)")
            }
            // Fallback: if the SDK insert times out or faces transient network issues,
            // attempt a direct REST insert with a slightly longer timeout.
            if let urlError = error as? URLError, urlError.code == .timedOut {
                do {
                    _ = try await SupabaseREST.postRow(to: "bookings", object: bookingData, timeout: 15.0)
                    if AppConfig.Features.enableDetailedLogging {
                        print("[Bookings] REST fallback insert succeeded for id=\(booking.id)")
                    }
                } catch let netErr as NetworkError {
                    if AppConfig.Features.enableDetailedLogging {
                        print("[Bookings] REST fallback failed with error: \(netErr)")
                        print("[Bookings] Booking data causing REST fallback error: \(bookingData)")
                    }
                    // Treat duplicate key conflict as success for idempotency (row likely created already)
                    if case .serverError(let code) = netErr, code == 409 {
                        if AppConfig.Features.enableDetailedLogging {
                            print("[Bookings] REST fallback returned 409 conflict; treating as success for id=\(booking.id)")
                        }
                    } else {
                        throw netErr
                    }
                }
            } else {
                throw error
            }
        }

        return booking.id
    }

    // Update booking status and payment_status columns
    func updateBookingStatusAndPayment(id: String, status: BookingStatus, paymentStatus: String) async throws {
        let payload = BookingStatusPaymentUpdate(
            status: status.dbValue,
            payment_status: paymentStatus,
            updated_at: DateFormats.rfc3339.string(from: Date())
        )

        _ = try await client
            .from("bookings")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    func getBookings(userId: String) async throws -> [BookingData] {
        let response: PostgrestResponse<[BookingRow]> = try await client
            .from("bookings")
            .select()
            .eq("user_id", value: userId)
            .order("booking_date", ascending: false)
            .order("start_time", ascending: false)
            .execute()

        return response.value.compactMap { row -> BookingData? in
            // Required fields validation: booking_date, start_time, end_time, status, payment_status must be present & parseable
            guard
                !row.booking_date.isEmpty,
                !row.start_time.isEmpty,
                !row.end_time.isEmpty,
                !row.status.isEmpty,
                !row.payment_status.isEmpty,
                let date = DateFormats.ymd.date(from: row.booking_date),
                let startTime = DateFormats.timeHMS.date(from: row.start_time),
                let endTime = DateFormats.timeHMS.date(from: row.end_time)
            else {
                // Skip rows with missing or invalid required fields gracefully
                if AppConfig.Features.enableDetailedLogging {
                    print("[Bookings] Skipping invalid booking row id=\(row.id) due to missing/invalid date or time fields")
                }
                return nil
            }

            return BookingData(
                id: row.id,
                userId: row.user_id ?? "",
                providerId: row.provider_id ?? "",
                serviceType: ServiceType.fromDb(row.service_type),
                date: date,
                startTime: startTime,
                endTime: endTime,
                durationHours: row.duration_hours,
                location: row.location,
                latitude: row.latitude,
                longitude: row.longitude,
                status: BookingStatus.fromDb(row.status),
                price: row.price,
                userNotes: row.user_notes,
                paymentStatus: row.payment_status
            )
        }
    }

    // MARK: - Marketplace: Host Services

    /// Fetch all active host services from Supabase
    func fetchHostServices() async throws -> [HostService] {
        let response: PostgrestResponse<[HostServiceRow]> = try await client
            .from("host_services")
            .select()
            .order("created_at", ascending: false)
            .execute()

        return response.value.map { row in
            HostService(
                id: row.id,
                service_name: row.service_name,
                price: row.price,
                price_per_hour: row.price_per_hour,
                currency: row.currency,
                rating: row.rating,
                city: row.city,
                service_type: row.service_type,
                description: row.description,
                specializations: row.specializations,
                equipment_included: row.equipment_included,
                images: row.images,
                is_active: row.is_active,
                total_bookings: row.total_bookings,
                provider_id: row.provider_id
            )
        }
    }

    // MARK: - Location History

    /// Saves location history record for a user.
    /// Note: The async nature ensures no blocking; no explicit main thread dispatch needed here.
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
    let user_id: String?
    let provider_id: String?
    let service_type: String
    // Legacy fields removed: date, duration

    let location: String
    let status: String
    let price: Double
    let created_at: String
    let booking_date: String     // yyyy-MM-dd
    let start_time: String       // HH:mm:ss
    let end_time: String         // HH:mm:ss
    let duration_hours: Int
    let latitude: Double?
    let longitude: Double?
    let payment_status: String
    let updated_at: String
    let user_notes: String?

    // New optional fields due to DB schema additions
    let currency: String?
    let payment_method: String?
    let transaction_id: String?
    let refund_id: String?
    let host_payout_status: String?
    let payout_date: String?
}

// Host service row as stored in Supabase
nonisolated(unsafe) struct HostServiceRow: Codable, Sendable {
    let id: String
    let service_name: String
    let price: Double?
    let price_per_hour: Double?
    let currency: String?
    let rating: Double?
    let city: String?
    let service_type: String?
    let description: String?
    let specializations: [String]?
    let equipment_included: [String]?
    let images: [String]?
    let is_active: Bool?
    let total_bookings: Int?
    let provider_id: String?
    let created_at: String?
    let updated_at: String?
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
    let user_id: String?              // Optional per SQL schema
    let provider_id: String?          // Optional per SQL schema
    let service_type: String          // Required string (must match allowed enum)

    // Legacy fields date and duration REMOVED, no longer present in schema

    let location: String              // Required
    let status: String                // Required
    let price: Double                 // Required
    let created_at: String            // RFC3339 string, required

    let booking_date: String          // yyyy-MM-dd, required
    let start_time: String            // HH:mm:ss, required
    let end_time: String              // HH:mm:ss, required
    let duration_hours: Int           // Required
    let latitude: Double?             // Optional
    let longitude: Double?            // Optional
    let payment_status: String        // Required
    let updated_at: String            // RFC3339 string, required
    let user_notes: String?           // Optional

    // New optional fields added in DB schema
    let currency: String?             // Optional
    let payment_method: String?       // Optional
    let transaction_id: String?       // Optional
    let refund_id: String?            // Optional
    let host_payout_status: String?  // Optional
    let payout_date: String?          // RFC3339 string, optional
}

nonisolated(unsafe) struct BookingStatusPaymentUpdate: Codable, Sendable {
    let status: String
    let payment_status: String
    let updated_at: String
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

struct BookingData: Identifiable, Sendable {
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
    let paymentStatus: String

    // Removed paymentId, paymentGateway, paymentMeta as they do not exist in DB schema anymore.
    let paymentId: String? = nil
    let paymentGateway: String? = nil
    let paymentMeta: String? = nil
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

/// Example function demonstrating safe usage of BundleResourceLoader for default.csv file loading.
/// Use this to load app bundled CSV resources safely and asynchronously.
func exampleLoadDefaultCSV() async throws -> String {
    let data = try BundleResourceLoader.loadFileData(named: "default", ext: "csv")
    guard let string = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "BundleResourceLoader", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to decode CSV as UTF-8 string"]) 
    }
    return string
}

/// --- Info.plist & Entitlements Checklist ---
///
/// Location Usage Description Keys:
/// - NSLocationWhenInUseUsageDescription
/// - NSLocationAlwaysAndWhenInUseUsageDescription
/// - NSLocationAlwaysUsageDescription
///
/// Network & Privacy:
/// - NSAppTransportSecurity (if needed for HTTP exceptions)
/// - NSAllowsArbitraryLoads (only if necessary)
///
/// Metal:
/// - Required device capabilities: metal
///
/// Make sure these keys are added with appropriate user-facing descriptions for location privacy,
/// network access, and hardware requirements to ensure smooth operation of the app.

