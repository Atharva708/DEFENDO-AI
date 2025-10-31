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

// NOTE: Ensure SupabaseManager.shared is initialized with your Supabase URL and anon key at app launch.
// Example:
// SupabaseManager.shared.configure(url: "https://YOUR-PROJECT.supabase.co", anonKey: "YOUR-ANON-KEY")

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
    /// Call this at app launch to ensure the Supabase client is configured early.
    /// Example: SupabaseService.configureAtLaunch()
    static func configureAtLaunch() {
        SupabaseService.shared.configureIfNeeded()
        SupabaseService.shared.printConfigurationDiagnostics()
    }
    /// Convenience: Call early in App init to assert configuration; logs any configuration problems.
    static func assertConfiguredAtLaunch() {
        do { try SupabaseService.shared.assertConfigured() } catch {
            print("[SupabaseService] Configuration assertion failed: \(error)")
        }
    }
    private var client: SupabaseClient!
    private var configuredURL: URL?
    private var configuredAnonKey: String?
    public var clientPublic: SupabaseClient { client }

    @discardableResult
    private func assertConfigured() throws -> Void {
        if client == nil {
            // Attempt configuration once more
            configureIfNeeded()
        }
        guard client != nil else {
            throw NSError(domain: "SupabaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Supabase client is not configured. Ensure SUPABASE_URL and SUPABASE_ANON_KEY are set in Info.plist and call SupabaseService.configureAtLaunch() early (e.g., in App init)."])
        }
    }

    // MARK: - Initialization & Configuration

    private init() {}

    /// Normalizes phone numbers for Supabase Auth.
    /// - Accepts E.164 numbers as-is (e.g., +15551234567)
    /// - If no '+' and the input looks like a 10-digit Indian mobile number, prefixes +91
    /// - Removes spaces and common separators
    /// - Throws if empty or clearly invalid
    private func normalizePhoneForAuth(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "OTP", code: 400, userInfo: [NSLocalizedDescriptionKey: "Phone number cannot be empty"])
        }
        // Remove spaces and separators
        let digitsPlus = trimmed.filter { $0.isNumber || $0 == "+" }
        if digitsPlus.first == "+" {
            // Already E.164-like; do a minimal sanity check
            guard digitsPlus.count >= 10 else {
                throw NSError(domain: "OTP", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid phone number"])
            }
            return digitsPlus
        }
        // No '+'; assume Indian mobile if 10 digits
        let digitsOnly = digitsPlus.filter { $0.isNumber }
        if digitsOnly.count == 10 {
            return "+91" + digitsOnly
        }
        // If someone passed a longer local format, try to be helpful but strict
        // Require at least 10 digits if no country code
        guard digitsOnly.count >= 10 else {
            throw NSError(domain: "OTP", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid 10-digit phone number or include country code (e.g., +91…)"])
        }
        // Default to +91 for Indian numbers if no country code provided
        return "+91" + digitsOnly
    }

    func configureIfNeeded() {
        if client != nil {
            return
        }
        let info = Bundle.main.infoDictionary

        // Read multiple environment URLs and keys from Info.plist
        let urlDev = (info?["SUPABASE_URL_DEV"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let urlProd = (info?["SUPABASE_URL_PROD"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let urlStaging = (info?["SUPABASE_URL_STAGING"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let keyDev = (info?["SUPABASE_ANON_KEY_DEV"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let keyProd = (info?["SUPABASE_ANON_KEY_PROD"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let keyStaging = (info?["SUPABASE_ANON_KEY_STAGING"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Determine environment based on build configuration
        #if DEBUG
        var resolvedURLString = urlDev
        var resolvedAnonKey = keyDev
        #else
        var resolvedURLString = urlProd
        var resolvedAnonKey = keyProd
        #endif

        // Check if override with staging is requested at runtime via plist flag
        let useStaging = (info?["USE_SUPABASE_STAGING"] as? Bool) == true
        if useStaging {
            if !urlStaging.isEmpty && !keyStaging.isEmpty {
                resolvedURLString = urlStaging
                resolvedAnonKey = keyStaging
            }
        }

        // If either resolved URL or key is empty, fallback to legacy keys from Info.plist first
        if resolvedURLString.isEmpty || resolvedAnonKey.isEmpty {
            let legacyURL = (info?["SUPABASE_URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let legacyKey = (info?["SUPABASE_ANON_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !legacyURL.isEmpty && !legacyKey.isEmpty {
                resolvedURLString = legacyURL
                resolvedAnonKey = legacyKey
            }
        }

        // If still empty, fallback to AppConfig
        if resolvedURLString.isEmpty || resolvedAnonKey.isEmpty {
            if !AppConfig.Supabase.url.isEmpty && !AppConfig.Supabase.anonKey.isEmpty {
                resolvedURLString = AppConfig.Supabase.url
                resolvedAnonKey = AppConfig.Supabase.anonKey
            }
        }

        guard let url = URL(string: resolvedURLString), !resolvedAnonKey.isEmpty else {
            print("[SupabaseService] Error: SUPABASE URL or ANON KEY missing or invalid. Set SUPABASE_URL_DEV/PROD/STAGING & SUPABASE_ANON_KEY_DEV/PROD/STAGING or legacy SUPABASE_URL/ANON_KEY in Info.plist, or AppConfig.Supabase.url/anonKey.")
            return
        }

        let options = SupabaseClientOptions()

        let client = SupabaseClient(supabaseURL: url, supabaseKey: resolvedAnonKey, options: options)
        self.client = client
        self.configuredURL = url
        self.configuredAnonKey = resolvedAnonKey

        let env: String
        if useStaging {
            env = "STAGING"
        } else if _isDebugAssertConfiguration() {
            env = "DEV"
        } else {
            env = "PROD"
        }
        print("[SupabaseService] Supabase client configured (\(env)): \(url)")
    }

    // MARK: - Phone Auth (OTP via Supabase Auth)
    // Uses Supabase's built-in phone authentication with OTP

    /// Start OTP by sending the phone number to Supabase Auth with Twilio
    /// - Parameter phoneNumber: E.164 formatted phone number, e.g. "+15551234567"
    func startOTP(for phoneNumber: String) async throws {
        try assertConfigured()
        
        let normalized = try normalizePhoneForAuth(phoneNumber)
        _ = try await client.auth.signInWithOTP(phone: normalized)
        
        if AppConfig.Features.enableDetailedLogging {
            print("[Auth] OTP sent to phone via Twilio: \(normalized)")
        }
    }

    /// Verify OTP with Supabase Auth; on success, sign in/up automatically
    /// - Returns: User ID if verification successful
    @discardableResult
    func verifyOTP(phoneNumber: String, code: String) async throws -> String? {
        try assertConfigured()
        
        let normalized = try normalizePhoneForAuth(phoneNumber)
        guard !code.isEmpty else {
            throw NSError(domain: "OTP", code: 400, userInfo: [NSLocalizedDescriptionKey: "OTP code is required"])
        }
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanCode.count >= 4 && cleanCode.count <= 6 && cleanCode.allSatisfy({ $0.isNumber }) else {
            throw NSError(domain: "OTP", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid OTP code"])
        }
        
        // Verify OTP with Supabase Auth
        let authResponse = try await client.auth.verifyOTP(phone: normalized, token: cleanCode, type: .sms)
        let user = authResponse.user
        
        if AppConfig.Features.enableDetailedLogging {
            print("[Auth] OTP verified successfully for user: \(user.id)")
        }
        
        // Store session locally
        storeSession(userId: user.id.uuidString)
        
        // Ensure user profile exists in our users table
        try await ensureUserProfileExists(userId: user.id.uuidString, phone: normalized)
        
        return user.id.uuidString
    }

    /// Login using a phone number by looking up the users table `phone` column.
    /// If a profile exists, stores a lightweight session locally and returns the user id.
    /// If not found and `createIfMissing` is true, it creates a basic profile and returns the id.
    @discardableResult
    func loginWithPhoneFromProfiles(_ phoneNumber: String, createIfMissing: Bool = true) async throws -> String {
        try assertConfigured()
        let normalized = try normalizePhoneForAuth(phoneNumber)
        
        guard normalized.hasPrefix("+") || CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: normalized)) else {
            throw NSError(domain: "SupabaseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid phone number format"])
        }

        do {
            let response: PostgrestResponse<[UserProfileRow]> = try await client
                .from("users")
                .select()
                .eq("phone", value: normalized)
                .limit(1)
                .execute()

            if let existing = response.value.first {
                storeSession(userId: existing.id)
                if AppConfig.Features.enableDetailedLogging {
                    print("[Auth] loginWithPhoneFromProfiles: found existing user id=\(existing.id)")
                }
                return existing.id
            }
        } catch {
            if AppConfig.Features.enableDetailedLogging {
                print("[Auth] loginWithPhoneFromProfiles: lookup error=\(error)")
            }
            // Continue to optional creation below
        }

        guard createIfMissing else {
            throw NSError(domain: "SupabaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user found with provided phone number"])
        }

        // Create minimal profile when missing
        let newId = UUID().uuidString
        let now = DateFormats.rfc3339.string(from: Date())
        let insert = UserProfileInsert(
            id: newId,
            email: "",
            full_name: normalized,
            phone: normalized,
            role: "user",
            safety_score: 85,
            created_at: now,
            updated_at: now
        )

        _ = try await client.from("users").insert(insert).execute()
        storeSession(userId: newId)
        if AppConfig.Features.enableDetailedLogging {
            print("[Auth] loginWithPhoneFromProfiles: created new user id=\(newId)")
        }
        return newId
    }

    /// Ensures a user profile exists in the users table for the given user ID and phone
    private func ensureUserProfileExists(userId: String, phone: String) async throws {
        try assertConfigured()
        let normalized = try normalizePhoneForAuth(phone)
        
        // Check if profile already exists
        do {
            let response: PostgrestResponse<[UserProfileRow]> = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
            
            if response.value.first != nil {
                // Profile exists, update phone if needed
                let update = UserProfileUpdate(
                    full_name: normalized, // Use normalized phone as display name if no name set
                    phone: normalized,
                    updated_at: DateFormats.rfc3339.string(from: Date())
                )
                _ = try await client
                    .from("users")
                    .update(update)
                    .eq("id", value: userId)
                    .execute()
                return
            }
        } catch {
            // Continue to create if not found
        }
        
        // Create new user profile
        let now = DateFormats.rfc3339.string(from: Date())
        let insert = UserProfileInsert(
            id: userId,
            email: "", // email not used in phone auth
            full_name: normalized, // Use normalized phone as display name initially
            phone: normalized,
            role: "user",
            safety_score: 85,
            created_at: now,
            updated_at: now
        )
        
        _ = try await client.from("users").insert(insert).execute()
        
        if AppConfig.Features.enableDetailedLogging {
            print("[Auth] Created user profile for phone: \(normalized)")
        }
    }
    
    // MARK: - Legal Acceptance Tracking
    
    /// Check if user has accepted terms and privacy policy
    func hasUserAcceptedLegal(userId: String) async throws -> Bool {
        try assertConfigured()
        
        let response: PostgrestResponse<[ProfileRow]> = try await client
            .from("profiles")
            .select("terms_accepted, privacy_policy_accepted")
            .eq("id", value: userId)
            .limit(1)
            .execute()
        
        guard let user = response.value.first else {
            return false
        }
        
        return (user.terms_accepted ?? false) && (user.privacy_policy_accepted ?? false)
    }
    
    /// Record user acceptance of terms and privacy policy
    func recordLegalAcceptance(userId: String, termsAccepted: Bool, privacyPolicyAccepted: Bool) async throws {
        try assertConfigured()
        
        print("[Legal] Recording acceptance for user: \(userId)")
        print("[Legal] termsAccepted: \(termsAccepted), privacyPolicyAccepted: \(privacyPolicyAccepted)")
        
        let update = LegalAcceptanceUpdate(
            terms_accepted: termsAccepted,
            privacy_policy_accepted: privacyPolicyAccepted,
            terms_accepted_at: termsAccepted ? DateFormats.rfc3339.string(from: Date()) : nil,
            privacy_policy_accepted_at: privacyPolicyAccepted ? DateFormats.rfc3339.string(from: Date()) : nil,
            updated_at: DateFormats.rfc3339.string(from: Date())
        )
        
        let response = try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
        
        print("[Legal] Update response received")
        
        if AppConfig.Features.enableDetailedLogging {
            print("[Legal] Recorded legal acceptance for user: \(userId)")
        }
    }

    // Persist a minimal session locally (replace with Keychain in production)
    func storeSession(userId: String) {
        UserDefaults.standard.set(userId, forKey: "session_user_id")
    }

    func currentSessionUserId() -> String? {
        UserDefaults.standard.string(forKey: "session_user_id")
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "session_user_id")
    }

    // MARK: - Caching
    private var companiesCache: [String: [Company]] = [:]
    private var securityFirmsCache: [String: [SecurityFirm]] = [:]
    private var securityGuardsCache: [String: [SecurityGuard]] = [:]
    private var cacheTimestamp: [String: Date] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // MARK: - Cache Management
    private func isCacheValid(for key: String) -> Bool {
        guard let timestamp = cacheTimestamp[key] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
    
    private func setCache<T>(_ data: [T], for key: String) {
        if let companies = data as? [Company] {
            companiesCache[key] = companies
        } else if let firms = data as? [SecurityFirm] {
            securityFirmsCache[key] = firms
        } else if let guards = data as? [SecurityGuard] {
            securityGuardsCache[key] = guards
        }
        cacheTimestamp[key] = Date()
    }
    
    private func getCachedData<T>(for key: String) -> [T]? {
        guard isCacheValid(for: key) else { return nil }
        
        if T.self == Company.self {
            return companiesCache[key] as? [T]
        } else if T.self == SecurityFirm.self {
            return securityFirmsCache[key] as? [T]
        } else if T.self == SecurityGuard.self {
            return securityGuardsCache[key] as? [T]
        }
        
        return nil
    }
    
    // MARK: - Cache Invalidation
    func invalidateCache(for key: String? = nil) {
        if let key = key {
            cacheTimestamp.removeValue(forKey: key)
            companiesCache.removeValue(forKey: key)
            securityFirmsCache.removeValue(forKey: key)
            securityGuardsCache.removeValue(forKey: key)
        } else {
            cacheTimestamp.removeAll()
            companiesCache.removeAll()
            securityFirmsCache.removeAll()
            securityGuardsCache.removeAll()
        }
    }

    // MARK: - User Profiles

    func createUserProfile(_ user: User) async throws {
        try assertConfigured()
        let now = DateFormats.rfc3339.string(from: Date())
        let profile = UserProfileInsert(
            id: user.id,
            email: user.email,
            full_name: user.name,
            phone: (try? normalizePhoneForAuth(user.phone)) ?? user.phone,
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
        try assertConfigured()
        let updates = UserProfileUpdate(
            full_name: user.name,
            phone: (try? normalizePhoneForAuth(user.phone)) ?? user.phone,
            updated_at: DateFormats.rfc3339.string(from: Date())
        )

        _ = try await client
            .from("users")
            .update(updates)
            .eq("id", value: user.id)
            .execute()
    }

    func getUserProfile(id: String) async throws -> User? {
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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
        try assertConfigured()
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

    // MARK: - Security Firms (Restaurants in Swiggy-like model)

    /// Fetch all security firms from host_profiles table
    func fetchSecurityFirms(limit: Int = 100, offset: Int = 0) async throws -> [SecurityFirm] {
        try assertConfigured()
        let cacheKey = "security_firms_\(limit)_\(offset)"
        
        // Check cache first
        if let cachedData: [SecurityFirm] = getCachedData(for: cacheKey) {
            if AppConfig.Features.enableDetailedLogging {
                print("[Cache] Returning cached security firms: \(cachedData.count)")
            }
            return cachedData
        }
        
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, address, avatar_url")
            // Removed `.eq("is_active", value: true)` as per instructions
            .order("company_name", ascending: true)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        let securityFirms = response.value.map { row in
            SecurityFirm(
                id: row.id,
                companyName: (row.company_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? (row.full_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Security Company",
                logoUrl: (row.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 },
                rating: nil,
                totalReviews: nil,
                location: row.address,
                address: row.address,
                phone: nil,
                email: nil,
                website: nil,
                servicesOffered: [],
                isVerified: false,
                isActive: true,
                deliveryTime: nil,
                minimumOrder: nil,
                deliveryFee: nil,
                currency: "USD",
                operatingHours: nil,
                coverageArea: [],
                certifications: [],
                insuranceInfo: nil,
                licenseNumber: nil,
                totalGuards: nil,
                availableGuards: nil,
                createdAt: nil,
                updatedAt: nil
            )
        }
        
        // Cache the results
        setCache(securityFirms, for: cacheKey)
        if AppConfig.Features.enableDetailedLogging {
            print("[Cache] Cached security firms: \(securityFirms.count)")
        }
        return securityFirms
    }

    /// Search security firms
    func searchSecurityFirms(query: String, limit: Int = 100, offset: Int = 0) async throws -> [SecurityFirm] {
        try assertConfigured()
        let like = "%" + query + "%"
        
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, address, avatar_url")
            .order("company_name", ascending: true)
            .execute()

        print(  "[Debug] host_profiles rows fetched: \(response.value.count)")

        return response.value.map { row in
            SecurityFirm(
                id: row.id,
                companyName: (row.company_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? (row.full_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Security Company",
                logoUrl: (row.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 },
                rating: nil,
                totalReviews: nil,
                location: row.address,
                address: row.address,
                phone: nil,
                email: nil,
                website: nil,
                servicesOffered: [],
                isVerified: false,
                isActive: true,
                deliveryTime: nil,
                minimumOrder: nil,
                deliveryFee: nil,
                currency: "USD",
                operatingHours: nil,
                coverageArea: [],
                certifications: [],
                insuranceInfo: nil,
                licenseNumber: nil,
                totalGuards: nil,
                availableGuards: nil,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    // MARK: - Security Guards (Dishes in Swiggy-like model)

    /// Fetch security guards for a specific company
    func fetchSecurityGuardsForCompany(companyId: String, limit: Int = 50, offset: Int = 0) async throws -> [SecurityGuard] {
        try assertConfigured()
        let cacheKey = "security_guards_\(companyId)_\(limit)_\(offset)"
        
        // Check cache first
        if let cachedData: [SecurityGuard] = getCachedData(for: cacheKey) {
            if AppConfig.Features.enableDetailedLogging {
                print("[Cache] Returning cached security guards for company \(companyId): \(cachedData.count)")
            }
            return cachedData
        }
        
        let guards = try await fetchEmployeesForCompany(companyId: companyId, limit: limit, offset: offset)
        
        // Cache the results
        setCache(guards, for: cacheKey)
        if AppConfig.Features.enableDetailedLogging {
            print("[Cache] Cached security guards for company \(companyId): \(guards.count)")
        }
        return guards
    }

    /// Search security guards
    func searchSecurityGuards(query: String, companyId: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [SecurityGuard] {
        try assertConfigured()
        // For now, we'll create mock data since employees table doesn't exist
        // In a real implementation, this would query the employees table
        let allGuards = createMockSecurityGuards(for: companyId ?? "default")
        return allGuards.filter { securityGuard in
            securityGuard.name.localizedCaseInsensitiveContains(query) ||
            securityGuard.specializations.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// Get security guard by ID
    func getSecurityGuard(guardId: String) async throws -> SecurityGuard? {
        try assertConfigured()
        // For now, we'll create mock data since employees table doesn't exist
        // In a real implementation, this would query the employees table
        let mockGuards = createMockSecurityGuards(for: "default")
        return mockGuards.first { $0.id == guardId }
    }

    /// Fetch employees for a given company from the employees table
    func fetchEmployeesForCompany(companyId: String, limit: Int = 50, offset: Int = 0) async throws -> [SecurityGuard] {
        try assertConfigured()
        let response: PostgrestResponse<[EmployeeRow]> = try await client
            .from("employees")
            .select("id, host_id, name, role, phone, photo_url, experience_years, location, created_at, updated_at, status")
            .eq("host_id", value: companyId)
            .order("name", ascending: true)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        return response.value.map { row in
            SecurityGuard(
                id: row.id,
                name: row.name,
                companyId: row.host_id,
                companyName: "", // Changed from nil to empty string as per instructions
                profileImageUrl: row.photo_url,
                rating: nil,
                experience: row.experience_years ?? 0,
                hourlyRate: 0,
                currency: "USD",
                specializations: [],
                certifications: [],
                languages: [],
                availability: .available,
                location: row.location,
                description: row.role,
                isVerified: false,
                totalBookings: nil,
                responseTime: nil,
                equipment: [],
                shiftPreferences: [],
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    // MARK: - Private Helper Methods

    private func createMockSecurityGuards(for companyId: String) -> [SecurityGuard] {
        let mockGuards = [
            SecurityGuard(
                id: "\(companyId)_guard_1",
                name: "John Smith",
                companyId: companyId,
                companyName: "SecureGuard Solutions",
                profileImageUrl: nil,
                rating: 4.8,
                experience: 5,
                hourlyRate: 25.0,
                currency: "USD",
                specializations: ["Personal Security", "Event Security", "Executive Protection"],
                certifications: ["CPP", "PSP"],
                languages: ["English", "Spanish"],
                availability: .available,
                location: "New York, NY",
                description: "Experienced security professional with 5+ years in personal and corporate security.",
                isVerified: true,
                totalBookings: 45,
                responseTime: 15,
                equipment: ["Radio", "Flashlight", "First Aid Kit"],
                shiftPreferences: ["day", "night"],
                createdAt: "2023-01-15T10:30:00.000Z",
                updatedAt: "2024-01-15T10:30:00.000Z"
            ),
            SecurityGuard(
                id: "\(companyId)_guard_2",
                name: "Maria Rodriguez",
                companyId: companyId,
                companyName: "SecureGuard Solutions",
                profileImageUrl: nil,
                rating: 4.9,
                experience: 7,
                hourlyRate: 30.0,
                currency: "USD",
                specializations: ["Corporate Security", "Access Control", "Surveillance"],
                certifications: ["CISSP", "CPSM"],
                languages: ["English", "Spanish", "Portuguese"],
                availability: .available,
                location: "New York, NY",
                description: "Senior security specialist with expertise in corporate environments.",
                isVerified: true,
                totalBookings: 78,
                responseTime: 10,
                equipment: ["Radio", "Tablet", "Access Control Card"],
                shiftPreferences: ["day"],
                createdAt: "2023-02-20T14:15:00.000Z",
                updatedAt: "2024-01-10T09:45:00.000Z"
            ),
            SecurityGuard(
                id: "\(companyId)_guard_3",
                name: "David Chen",
                companyId: companyId,
                companyName: "SecureGuard Solutions",
                profileImageUrl: nil,
                rating: 4.7,
                experience: 3,
                hourlyRate: 22.0,
                currency: "USD",
                specializations: ["Event Security", "Crowd Control"],
                certifications: ["CPO"],
                languages: ["English", "Mandarin"],
                availability: .busy,
                location: "New York, NY",
                description: "Dedicated event security specialist with crowd management expertise.",
                isVerified: true,
                totalBookings: 32,
                responseTime: 20,
                equipment: ["Radio", "Crowd Control Barrier"],
                shiftPreferences: ["night", "weekend"],
                createdAt: "2023-03-10T16:30:00.000Z",
                updatedAt: "2024-01-05T11:20:00.000Z"
            ),
            SecurityGuard(
                id: "\(companyId)_guard_4",
                name: "Sarah Johnson",
                companyId: companyId,
                companyName: "SecureGuard Solutions",
                profileImageUrl: nil,
                rating: 4.9,
                experience: 6,
                hourlyRate: 28.0,
                currency: "USD",
                specializations: ["Executive Protection", "Personal Security"],
                certifications: ["EPP", "CPP"],
                languages: ["English", "French"],
                availability: .available,
                location: "New York, NY",
                description: "Executive protection specialist with high-profile client experience.",
                isVerified: true,
                totalBookings: 56,
                responseTime: 12,
                equipment: ["Radio", "Body Armor", "First Aid Kit"],
                shiftPreferences: ["day", "night"],
                createdAt: "2023-01-25T08:45:00.000Z",
                updatedAt: "2024-01-12T13:15:00.000Z"
            ),
            SecurityGuard(
                id: "\(companyId)_guard_5",
                name: "Michael Brown",
                companyId: companyId,
                companyName: "SecureGuard Solutions",
                profileImageUrl: nil,
                rating: 4.6,
                experience: 4,
                hourlyRate: 24.0,
                currency: "USD",
                specializations: ["Patrol Security", "Access Control"],
                certifications: ["PSO"],
                languages: ["English"],
                availability: .onDuty,
                location: "New York, NY",
                description: "Reliable patrol security officer with strong attention to detail.",
                isVerified: true,
                totalBookings: 41,
                responseTime: 18,
                equipment: ["Radio", "Patrol Vehicle", "Flashlight"],
                shiftPreferences: ["night"],
                createdAt: "2023-04-05T12:00:00.000Z",
                updatedAt: "2024-01-08T15:30:00.000Z"
            )
        ]
        
        return mockGuards
    }

    // MARK: - Marketplace: Companies & Company Services
    
    /// Fetch all companies from host_profiles table with optimized query and caching
    func fetchCompanies(limit: Int = 100, offset: Int = 0) async throws -> [Company] {
        try assertConfigured()
        let cacheKey = "companies_\(limit)_\(offset)"
        
        // Check cache first
        if let cachedData: [Company] = getCachedData(for: cacheKey) {
            if AppConfig.Features.enableDetailedLogging {
                print("[Cache] Returning cached companies: \(cachedData.count)")
            }
            return cachedData
        }
        
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, address, avatar_url")
            .order("company_name", ascending: true)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        let companies = response.value.map { row in
            Company(
                id: row.id,
                name: (row.company_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? (row.full_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Security Company",
                logo_url: (row.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 },
                rating: nil,
                location: row.address,
                description: nil
            )
        }
        
        // Cache the results
        setCache(companies, for: cacheKey)
        if AppConfig.Features.enableDetailedLogging {
            print("[Cache] Cached companies: \(companies.count)")
        }
        return companies
    }

    /// Fetch all companies as card data for marketplace display with optimized single query
    func fetchAllCompanies(limit: Int = 100, offset: Int = 0) async throws -> [CompanyCard] {
        try assertConfigured()
        let cacheKey = "company_cards_\(limit)_\(offset)"
        
        // Check cache first
        if let cachedData: [CompanyCard] = getCachedData(for: cacheKey) {
            if AppConfig.Features.enableDetailedLogging {
                print("[Cache] Returning cached company cards: \(cachedData.count)")
            }
            return cachedData
        }
        
        // Single optimized query with all necessary data
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, address, avatar_url")
            .order("company_name", ascending: true)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        let companyCards = response.value.map { row in
            CompanyCard(
                id: row.id,
                companyName: (row.company_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? (row.full_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Security Company",
                logoUrl: (row.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 },
                rating: nil,
                city: row.address,
                previewImages: [], // Will be populated when service images are available
                hourlyRate: nil, // Not available in host_profiles
                description: nil,
                serviceTypes: nil,
                email: nil,
                phone: nil,
                verified: false,
                reviews: nil,
                createdAt: nil,
                updatedAt: nil
            )
        }
        
        // Cache the results
        setCache(companyCards, for: cacheKey)
        if AppConfig.Features.enableDetailedLogging {
            print("[Cache] Cached company cards: \(companyCards.count)")
        }
        return companyCards
    }

    /// Search companies with optimized query
    func searchCompanies(offering query: String, limit: Int = 100, offset: Int = 0) async throws -> [CompanyCard] {
        try assertConfigured()
        let like = "%" + query + "%"
        
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, address, avatar_url")
            .or("company_name.ilike.\(like),full_name.ilike.\(like),address.ilike.\(like)")
            .order("company_name", ascending: true)
            .execute()

        return response.value.map { row in
            CompanyCard(
                id: row.id,
                companyName: (row.company_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? (row.full_name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Security Company",
                logoUrl: (row.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 },
                rating: nil,
                city: row.address,
                previewImages: [],
                hourlyRate: nil,
                description: nil,
                serviceTypes: nil,
                email: nil,
                phone: nil,
                verified: false,
                reviews: nil,
                createdAt: nil,
                updatedAt: nil
            )
        }
    }

    /// Fetch services for a given company with optimized query
    func fetchServicesForCompany(companyId: String) async throws -> [CompanyService] {
        try assertConfigured()
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, services_offered")
            .eq("id", value: companyId)
            .execute()

        guard let provider = response.value.first else {
            return []
        }

        // Convert services_offered array to individual services
        let serviceTypes = provider.services_offered ?? []
        return serviceTypes.enumerated().map { index, serviceType in
            CompanyService(
                id: "\(companyId)_\(index)",
                company_id: companyId,
                service_name: serviceType.replacingOccurrences(of: "_", with: " ").capitalized,
                service_type: serviceType,
                price: nil, // Not available in host_profiles
                availability: true,
                image_url: nil
            )
        }
    }

    /// Fetch all subcategory services for a specific host (provider) - simplified approach
    func fetchSubcategoryServices(for hostId: String, matching query: String? = nil) async throws -> [HostService] {
        try assertConfigured()
        let response: PostgrestResponse<[HostProfileRow]> = try await client
            .from("host_profiles")
            .select("id, company_name, services_offered")
            .eq("id", value: hostId)
            .execute()

        guard let provider = response.value.first else {
            return []
        }

        let serviceTypes = provider.services_offered ?? []
        let filteredTypes = query?.isEmpty == false ? 
            serviceTypes.filter { $0.localizedCaseInsensitiveContains(query!) } : 
            serviceTypes

        return filteredTypes.enumerated().map { index, serviceType in
            HostService(
                id: "\(hostId)_\(index)",
                service_name: serviceType.replacingOccurrences(of: "_", with: " ").capitalized,
                price: nil, // Not available in host_profiles
                price_per_hour: nil,
                currency: "USD",
                rating: nil,
                city: nil,
                service_type: serviceType,
                description: nil,
                specializations: nil,
                equipment_included: nil,
                images: nil,
                is_active: true,
                total_bookings: 0,
                provider_id: hostId
            )
        }
    }

    // MARK: - Location History

    /// Saves location history record for a user.
    /// Note: The async nature ensures no blocking; no explicit main thread dispatch needed here.
    func saveLocationHistory(userId: String, location: LocationHistoryData) async throws {
        try assertConfigured()
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
        configureIfNeeded()
        return Empty().eraseToAnyPublisher()
    }

    // MARK: - Diagnostics
    func printConfigurationDiagnostics() {
        let info = Bundle.main.infoDictionary
        let urlString = (info?["SUPABASE_URL"] as? String) ?? "<missing>"
        let anonKey = (info?["SUPABASE_ANON_KEY"] as? String) ?? "<missing>"
        #if DEBUG
        let urlStringDebug = (info?["SUPABASE_URL_DEBUG"] as? String) ?? "<unset>"
        let anonKeyDebug = (info?["SUPABASE_ANON_KEY_DEBUG"] as? String) ?? "<unset>"
        #endif
        let infoDev = (info?["SUPABASE_URL_DEV"] as? String) ?? "<unset>"
        let infoProd = (info?["SUPABASE_URL_PROD"] as? String) ?? "<unset>"
        let infoStaging = (info?["SUPABASE_URL_STAGING"] as? String) ?? "<unset>"
        let useStaging = (info?["USE_SUPABASE_STAGING"] as? Bool) == true

        let env: String
        if useStaging {
            env = "STAGING"
        } else if _isDebugAssertConfiguration() {
            env = "DEV"
        } else {
            env = "PROD"
        }

        print("[SupabaseService] Diagnostics(\(env)) -> URL: \(configuredURL?.absoluteString.prefix(60) ?? "<none>")… | Key: \(configuredAnonKey?.isEmpty == false ? "<provided>" : "<empty>")")
        #if DEBUG
        print("[SupabaseService] DEBUG overrides -> URL_DEBUG: \(urlStringDebug.prefix(60))… | KEY_DEBUG: \(anonKeyDebug.isEmpty ? "<empty>" : "<provided>")")
        #endif
        if client == nil { print("[SupabaseService] Warning: client is not configured yet.") }
        if let configuredURL {
            print("[SupabaseService] Configured URL: \(configuredURL)")
        }
    }

    // MARK: - Retry Helper
    /// Executes an async operation with exponential backoff for transient URL errors.
    func withRetry<T>(maxAttempts: Int = 3, initialDelay: TimeInterval = 0.5, _ op: @escaping () async throws -> T) async throws -> T {
        let transient: Set<URLError.Code> = [.timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .notConnectedToInternet]
        var attempt = 0
        var lastError: Error?
        var delay = initialDelay
        while attempt < maxAttempts {
            attempt += 1
            do {
                return try await op()
            } catch let urlErr as URLError {
                lastError = urlErr
                if transient.contains(urlErr.code) && attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2
                    continue
                } else {
                    throw urlErr
                }
            } catch {
                lastError = error
                throw error
            }
        }
        throw lastError ?? NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown retry failure"])        
    }

    // MARK: - Connectivity Test
    /// Performs a lightweight fetch to confirm the client can reach Supabase.
    func connectivityTest() async {
        guard let base = configuredURL, let anonKey = configuredAnonKey else {
            print("[SupabaseService] connectivityTest: client not configured")
            return
        }
        do {
            // HEAD request to PostgREST root to validate reachability
            let openapiURL = base.appendingPathComponent("rest/v1/")
            var req = URLRequest(url: openapiURL)
            req.httpMethod = "HEAD"
            req.setValue(anonKey, forHTTPHeaderField: "apikey")
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                print("[SupabaseService] connectivityTest status: \(http.statusCode)")
            } else {
                print("[SupabaseService] connectivityTest: non-HTTP response")
            }
        } catch {
            print("[SupabaseService] connectivityTest error: \(error)")
        }
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
    let terms_accepted: Bool?
    let privacy_policy_accepted: Bool?
    let terms_accepted_at: String?
    let privacy_policy_accepted_at: String?
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
    let services_offered: [String]?
    let verified: Bool?
    let rating: Double?
    let reviews: Int?
    let created_at: String?
    let updated_at: String?
    let logo_path: String?
}

// Service provider row from Supabase service_providers table
nonisolated(unsafe) struct ServiceProviderRow: Codable, Sendable {
    let id: String
    let user_id: String?
    let company_name: String
    let description: String?
    let service_types: [String]?
    let license_number: String?
    let insurance_info: String? // JSONB as string
    let verification_status: String?
    let rating: Double?
    let total_reviews: Int?
    let hourly_rate: Double?
    let is_available: Bool?
    let coverage_area: String? // JSONB as string
    let created_at: String?
    let updated_at: String?
}


nonisolated(unsafe) struct EmployeeRow: Codable, Sendable {
    let id: String
    let host_id: String
    let name: String
    let role: String?
    let phone: String?
    let photo_url: String?
    let experience_years: Int?
    let location: String?
    let created_at: String?
    let updated_at: String?
    let status: String?
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
    let full_name: String?
    let phone: String?
    let updated_at: String
}

nonisolated(unsafe) struct LegalAcceptanceUpdate: Codable, Sendable {
    let terms_accepted: Bool
    let privacy_policy_accepted: Bool
    let terms_accepted_at: String?
    let privacy_policy_accepted_at: String?
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

struct SupabaseCompanyCardData: Identifiable, Sendable, Codable {
    let id: String               // provider_id (host id)
    let companyName: String
    let logoUrl: String?
    let rating: Double?
    let city: String?
    let previewImages: [String]
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




















