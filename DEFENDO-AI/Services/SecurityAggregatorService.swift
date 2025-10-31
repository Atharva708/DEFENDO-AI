//
//  SecurityAggregatorService.swift
//  DEFENDO-AI
//
//  Swiggy-like aggregator service for security firms and guards
//

import Foundation
import Combine
import SwiftUI
import Supabase

// MARK: - Security Aggregator Service
@MainActor
class SecurityAggregatorService: ObservableObject {
    static let shared = SecurityAggregatorService()
    
    // MARK: - Published Properties
    @Published var securityFirms: [SecurityFirm] = []
    @Published var selectedFirm: SecurityFirm?
    @Published var securityGuards: [SecurityGuard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMoreData = true
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    private var currentOffset = 0
    private let pageSize = 20
    private var searchQuery = ""
    
    // MARK: - Caching
    private var cache: [String: [SecurityFirm]] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load initial security firms
    func loadSecurityFirms() async {
        await loadSecurityFirms(query: "", reset: true)
    }
    
    /// Search security firms
    func searchSecurityFirms(query: String) async {
        searchQuery = query
        await loadSecurityFirms(query: query, reset: true)
    }
    
    /// Load more security firms for pagination
    func loadMoreSecurityFirms() async {
        guard !isLoading && hasMoreData else { return }
        await loadSecurityFirms(query: searchQuery, reset: false)
    }
    
    /// Refresh security firms data
    func refreshSecurityFirms() async {
        clearCache()
        await loadSecurityFirms(query: searchQuery, reset: true)
    }
    
    /// Load security guards for a specific firm
    func loadSecurityGuardsForFirm(firmId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            securityGuards = try await supabaseService.fetchSecurityGuardsForCompany(companyId: firmId)
            selectedFirm = securityFirms.first { $0.id == firmId }
        } catch {
            errorMessage = handleError(error)
        }
        
        isLoading = false
    }
    
    /// Search security guards
    func searchSecurityGuards(query: String, firmId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            securityGuards = try await supabaseService.searchSecurityGuards(
                query: query,
                companyId: firmId ?? selectedFirm?.id
            )
        } catch {
            errorMessage = handleError(error)
        }
        
        isLoading = false
    }
    
    /// Set selected security firm
    func setSelectedFirm(_ firm: SecurityFirm) {
        selectedFirm = firm
    }
    
    /// Get security firm by ID
    func getSecurityFirm(id: String) -> SecurityFirm? {
        return securityFirms.first { $0.id == id }
    }
    
    /// Get security guard by ID
    func getSecurityGuard(id: String) -> SecurityGuard? {
        return securityGuards.first { $0.id == id }
    }
    
    // MARK: - Private Methods
    
    private func loadSecurityFirms(query: String, reset: Bool) async {
        if reset {
            currentOffset = 0
            hasMoreData = true
            securityFirms.removeAll()
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newFirms = try await fetchSecurityFirms(query: query, offset: currentOffset)
            
            if reset {
                securityFirms = newFirms
            } else {
                securityFirms.append(contentsOf: newFirms)
            }
            
            currentOffset += newFirms.count
            hasMoreData = newFirms.count == pageSize
            
        } catch {
            errorMessage = handleError(error)
        }
        
        isLoading = false
    }
    
    private func fetchSecurityFirms(query: String, offset: Int) async throws -> [SecurityFirm] {
        let cacheKey = "\(query)_\(offset)"
        
        // Check cache first
        if let cachedData = getCachedData(for: cacheKey) {
            return cachedData
        }
        
        let firms: [SecurityFirm]
        
        if query.isEmpty {
            firms = try await supabaseService.fetchSecurityFirms(limit: pageSize, offset: offset)
        } else {
            firms = try await supabaseService.searchSecurityFirms(query: query, limit: pageSize, offset: offset)
        }
        
        // Cache the results
        setCache(firms, for: cacheKey)
        return firms
    }
    
    private func handleError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Please check your network and try again."
            case .timedOut:
                return "Request timed out. Please try again."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        } else if let supabaseError = error as? PostgrestError {
            return "Database error: \(supabaseError.message)"
        } else {
            return "Failed to load security firms: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cache Management
    
    private func isCacheValid(for key: String) -> Bool {
        guard let timestamp = cacheTimestamps[key] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
    
    private func setCache(_ data: [SecurityFirm], for key: String) {
        cache[key] = data
        cacheTimestamps[key] = Date()
    }
    
    private func getCachedData(for key: String) -> [SecurityFirm]? {
        guard isCacheValid(for: key) else { return nil }
        return cache[key]
    }
    
    private func clearCache() {
        cache.removeAll()
        cacheTimestamps.removeAll()
    }
}

// MARK: - Security Firm Extensions
extension SecurityFirm {
    
    /// Get formatted rating display
    var ratingDisplay: String {
        guard let rating = rating else { return "No rating" }
        return String(format: "%.1f", rating)
    }
    
    /// Get formatted reviews count
    var reviewsDisplay: String {
        guard let reviews = totalReviews else { return "No reviews" }
        return "\(reviews) reviews"
    }
    
    /// Get formatted delivery time
    var deliveryTimeDisplay: String {
        guard let time = deliveryTime else { return "Contact for timing" }
        return "\(time) min response"
    }
    
    /// Get formatted minimum order
    var minimumOrderDisplay: String {
        guard let minimum = minimumOrder else { return "No minimum" }
        return "Min: $\(String(format: "%.0f", minimum))"
    }
    
    /// Check if firm is currently open
    var isCurrentlyOpen: Bool {
        // For now, assume all firms are open
        // In a real implementation, this would check operating hours
        return isActive
    }
    
    /// Get availability status
    var availabilityStatus: String {
        if !isActive {
            return "Closed"
        } else if availableGuards == 0 {
            return "No guards available"
        } else {
            return "Open"
        }
    }
}

// MARK: - Security Guard Extensions
extension SecurityGuard {
    
    /// Get formatted rating display
    var ratingDisplay: String {
        guard let rating = rating else { return "No rating" }
        return String(format: "%.1f", rating)
    }
    
    /// Get formatted experience
    var experienceDisplay: String {
        guard let experience = experience else { return "New" }
        return "\(experience) years"
    }
    
    /// Get formatted hourly rate
    var hourlyRateDisplay: String {
        return "$\(String(format: "%.0f", hourlyRate))/hr"
    }
    
    /// Get formatted response time
    var responseTimeDisplay: String {
        guard let time = responseTime else { return "Contact for timing" }
        return "\(time) min response"
    }
    
    /// Get formatted total bookings
    var totalBookingsDisplay: String {
        guard let bookings = totalBookings else { return "New" }
        return "\(bookings) bookings"
    }
    
    /// Get availability color
    var availabilityColor: Color {
        return availability.color
    }
    
    /// Get availability status text
    var availabilityStatus: String {
        return availability.displayName
    }
    
    /// Check if guard is available for booking
    var isAvailableForBooking: Bool {
        return availability == .available
    }
}

