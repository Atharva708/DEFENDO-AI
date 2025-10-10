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

        // Allowed service types per DB schema - include our app-supported values
        let allowedServiceTypes = [
            "bodyguard",
            "guard",
            "security_guard",
            "drone_patrol",
            "surveillance",
            "escort",
            "emergency"
        ]
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
        // Sanitize optional strings
        let userNotesSanitized: String? = {
            guard let notes = booking.userNotes else { return nil }
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

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
            user_notes: userNotesSanitized,
            // Now that the columns exist, populate them
            currency: AppConfig.Payments.defaultCurrencyCode,
            payment_method: booking.paymentGateway,
            transaction_id: booking.paymentId,
            refund_id: nil,
            host_payout_status: nil,
            payout_date: nil
        )

        if AppConfig.Features.enableDetailedLogging {
            print("[Bookings] Attempting to insert booking: \(bookingData)")
        }

        // Attempt up to 3 retries for transient network errors, then REST fallback.
        let transientCodes: Set<URLError.Code> = [.timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .notConnectedToInternet]
        var lastError: Error? = nil
        for attempt in 1...3 {
            do {
                _ = try await client
                    .from("bookings")
                    .insert(bookingData)
                    .execute()
                if AppConfig.Features.enableDetailedLogging {
                    print("[Bookings] SDK insert succeeded for id=\(booking.id) on attempt #\(attempt)")
                }
                lastError = nil
                break
            } catch {
                lastError = error
                if let urlError = error as? URLError, transientCodes.contains(urlError.code) {
                    if AppConfig.Features.enableDetailedLogging {
                        print("[Bookings] Transient error (\(urlError.code.rawValue)) on attempt #\(attempt); retrying…")
                    }
                    // Exponential backoff: 0.5s, 1.0s, 2.0s
                    let delay = UInt64(500_000_000) << (attempt - 1)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                } else {
                    // Non-transient error; break to fallback
                    break
                }
            }
        }

        if let error = lastError {
            if AppConfig.Features.enableDetailedLogging {
                print("[Bookings] SDK insert failed after retries with error: \(error)")
                print("[Bookings] Booking data causing error: \(bookingData)")
            }
            // REST fallback with longer timeout
            do {
                _ = try await SupabaseREST.postRow(to: "bookings", object: bookingData, timeout: 20.0)
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
                paymentStatus: row.payment_status,
                paymentId: nil,
                paymentGateway: nil,
                paymentMeta: nil
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

    // MARK: - Marketplace: Companies & Company Services

    /// Fetch all companies (hosts) from Supabase `host_profiles`
    func fetchCompanies() async throws -> [Company] {
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()

        return response.value.map { row in
            Company(
                id: row.id,
                name: row.company_name ?? row.full_name ?? "Security Company",
                logo_url: row.logo_path ?? row.avatar_url,
                rating: row.rating,
                location: row.address,
                description: nil
            )
        }
    }

    /// Fetch services for a given company from `host_services`
    func fetchServicesForCompany(companyId: String) async throws -> [CompanyService] {
        let response: PostgrestResponse<[HostServiceRow]> = try await client
            .from("host_services")
            .select()
            .eq("provider_id", value: companyId)
            .order("created_at", ascending: false)
            .execute()

        return response.value.map { row in
            CompanyService(
                id: row.id,
                company_id: row.provider_id ?? companyId,
                service_name: row.service_name,
                service_type: row.service_type ?? "",
                price: row.price,
                availability: row.is_active ?? true,
                image_url: row.images?.first
            )
        }
    }

    /// Search companies (hosts) that offer services matching the query.
    /// Aggregates from `host_services` and joins with `host_profiles`.
    func searchCompanies(offering query: String, limit: Int = 20, offset: Int = 0) async throws -> [SupabaseCompanyCardData] {
        let like = "%" + query + "%"
        let servicesResp: PostgrestResponse<[HostServiceRow]> = try await client
            .from("host_services")
            .select()
            .or("service_type.ilike.\(like),service_name.ilike.\(like)")
            .order("created_at", ascending: false)
            .range(from: offset, to: max(offset, offset + limit - 1))
            .execute()

        let services = servicesResp.value
        let servicesByProvider = Dictionary(grouping: services, by: { $0.provider_id ?? "" }).filter { !$0.key.isEmpty }
        let providerIds = Array(servicesByProvider.keys)
        if providerIds.isEmpty { return [] }

        let hostsResp: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select()
            .in("id", values: providerIds)
            .execute()

        let hostsById = Dictionary(uniqueKeysWithValues: hostsResp.value.map { ($0.id, $0) })
        var cards: [SupabaseCompanyCardData] = []
        for providerId in providerIds {
            guard let rows = servicesByProvider[providerId], let host = hostsById[providerId] else { continue }
            let previews = rows.compactMap { $0.images?.first }.prefix(3)
            let name = host.company_name ?? host.full_name ?? "Company"
            let logo = host.logo_path ?? host.avatar_url
            let city = host.address
            let rating = host.rating
            cards.append(SupabaseCompanyCardData(id: providerId, companyName: name, logoUrl: logo, rating: rating, city: city, previewImages: Array(previews)))
        }
        return cards
    }

    /// Fetch all subcategory services for a specific host (provider)
    func fetchSubcategoryServices(for hostId: String, matching query: String? = nil) async throws -> [HostService] {
        var builder = client
            .from("host_services")
            .select()
            .eq("provider_id", value: hostId)
            // defer ordering until after optional filters
            

        if let q = query, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let like = "%" + q + "%"
            builder = builder.or("service_type.ilike.\(like),service_name.ilike.\(like)")
        }
        // apply ordering last to avoid type mismatch on builder
        builder = builder.order("service_name", ascending: true) as! PostgrestFilterBuilder

        let response: PostgrestResponse<[HostServiceRow]> = try await builder
            .order("service_name", ascending: true)
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

    // MARK: - Marketplace (Swiggy-style): Joined Services

    struct MarketplaceServiceCard: Identifiable, Sendable {
        let id: String                 // service_id
        let service_name: String
        let image_url: String?
        let price_per_hour: Double?
        let currency: String?
        let rating: Double?
        let total_bookings: Int?
        let host_id: String
        let company_name: String
        let logo_url: String?
    }

    /// Fetch active services joined with host/company details (client-side join)
    func fetchActiveServicesWithHosts() async throws -> [MarketplaceServiceCard] {
        let servicesResp: PostgrestResponse<[HostServiceRow]> = try await client
            .from("host_services")
            .select()
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()

        let services = servicesResp.value
        let providerIds = Array(Set(services.compactMap { $0.provider_id }))
        var hostsById: [String: HostProfileRow] = [:]
        if !providerIds.isEmpty {
            let hostsResp: PostgrestResponse<[HostProfileRow]> = try await client
                .from("host_profiles")
                .select()
                .in("id", values: providerIds)
                .execute()
            hostsById = Dictionary(uniqueKeysWithValues: hostsResp.value.map { ($0.id, $0) })
        }

        return services.map { row in
            let host = hostsById[row.provider_id ?? ""]
            return MarketplaceServiceCard(
                id: row.id,
                service_name: row.service_name,
                image_url: row.images?.first,
                price_per_hour: row.price_per_hour,
                currency: row.currency,
                rating: row.rating,
                total_bookings: row.total_bookings,
                host_id: row.provider_id ?? "",
                company_name: host?.company_name ?? host?.full_name ?? "Company",
                logo_url: host?.logo_path ?? host?.avatar_url
            )
        }
    }

    // MARK: - Subcategories

    nonisolated(unsafe) struct HostServiceSubcategoryRow: Codable, Sendable {
        let id: String
        let service_id: String
        let host_id: String
        let subcategory_key: String
        let subcategory_label: String
        let subcategory_type: String?
        let price_per_hour: Double
        let currency: String
        let description: String?
        let is_active: Bool
        let display_order: Int?
        let created_at: String?
        let updated_at: String?
    }

    struct ServiceSubcategory: Identifiable, Sendable {
        let id: String
        let service_id: String
        let host_id: String
        let label: String
        let price_per_hour: Double
        let currency: String
        let description: String?
        let is_active: Bool
    }

    func fetchSubcategories(serviceId: String, hostId: String) async throws -> [ServiceSubcategory] {
        let resp: PostgrestResponse<[HostServiceSubcategoryRow]> = try await client
            .from("host_service_subcategories")
            .select()
            .eq("service_id", value: serviceId)
            .eq("host_id", value: hostId)
            .order("display_order", ascending: true)
            .execute()

        return resp.value.map { row in
            ServiceSubcategory(
                id: row.id,
                service_id: row.service_id,
                host_id: row.host_id,
                label: row.subcategory_label,
                price_per_hour: row.price_per_hour,
                currency: row.currency,
                description: row.description,
                is_active: row.is_active
            )
        }
    }

    /// Fetch companies that currently have active rows in host_services
    func fetchCompaniesFromHostServices() async throws -> [Company] {
        let servicesResp: PostgrestResponse<[HostServiceRow]> = try await client
            .from("host_services")
            .select("provider_id")
            .eq("is_active", value: true)
            .execute()
        let providerIds = Array(Set(servicesResp.value.compactMap { $0.provider_id }))
        guard !providerIds.isEmpty else { return [] }

        let hostsResp: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select()
            .in("id", values: providerIds)
            .execute()

        return hostsResp.value.map { row in
            Company(
                id: row.id,
                name: row.company_name ?? row.full_name ?? "Security Company",
                logo_url: row.logo_path ?? row.avatar_url,
                rating: row.rating,
                location: row.address,
                description: nil
            )
        }
    }

    // MARK: - Employees by Host

    nonisolated(unsafe) struct EmployeeRow: Codable, Sendable {
        let id: String
        let host_id: String
        let name: String
        let role: String
        let phone: String
        let photo_url: String?
        let experience_years: Int?
        let location: String?
        let status: String
        let created_at: String?
        let updated_at: String?
    }

    func fetchEmployeesForHost(hostId: String) async throws -> [EmployeeRow] {
        let resp: PostgrestResponse<[EmployeeRow]> = try await client
            .from("employees")
            .select()
            .eq("host_id", value: hostId)
            .order("updated_at", ascending: false)
            .execute()
        return resp.value
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

// Company row from Supabase host_profiles
nonisolated(unsafe) struct HostProfileRow: Codable, Sendable {
    let id: String
    let email: String?
    let full_name: String?
    let company_name: String?
    let avatar_url: String?
    let phone: String?
    let address: String?
    let services_offered: [String]? // generic array
    let verified: Bool?
    let rating: Double?
    let reviews: Int?
    let created_at: String?
    let updated_at: String?
    let logo_path: String?
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

    // Client-side payment metadata (not persisted to DB, shown in UI only)
    let paymentId: String?
    let paymentGateway: String?
    let paymentMeta: String?
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

// MARK: - Marketplace App Models

struct Company: Identifiable, Sendable, Codable {
    let id: String
    let name: String
    let logo_url: String?
    let rating: Double?
    let location: String?
    let description: String?
}

struct CompanyService: Identifiable, Sendable, Codable {
    let id: String
    let company_id: String
    let service_name: String
    let service_type: String
    let price: Double?
    let availability: Bool
    let image_url: String?
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

