import Foundation
import Supabase
import Combine

// MARK: - Marketplace Service
/// Optimized service for marketplace operations with caching, error handling, and performance optimizations
@MainActor
class MarketplaceService: ObservableObject {
    static let shared = MarketplaceService()
    
    // MARK: - Published Properties
    @Published var companies: [CompanyCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMoreData = true
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    private var currentOffset = 0
    private let pageSize = 20
    private var searchQuery = ""
    
    // MARK: - Caching
    private var cache: [String: [CompanyCard]] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load initial companies with caching
    func loadCompanies() async {
        await loadCompanies(query: "", reset: true)
    }
    
    /// Search companies with debouncing
    func searchCompanies(query: String) async {
        searchQuery = query
        await loadCompanies(query: query, reset: true)
    }
    
    /// Load more companies for pagination
    func loadMoreCompanies() async {
        guard !isLoading && hasMoreData else { return }
        await loadCompanies(query: searchQuery, reset: false)
    }
    
    /// Refresh companies data
    func refreshCompanies() async {
        clearCache()
        await loadCompanies(query: searchQuery, reset: true)
    }
    
    // MARK: - Private Methods
    
    private func loadCompanies(query: String, reset: Bool) async {
        if reset {
            currentOffset = 0
            hasMoreData = true
            companies.removeAll()
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newCompanies = try await fetchCompanies(query: query, offset: currentOffset)
            
            if reset {
                companies = newCompanies
            } else {
                companies.append(contentsOf: newCompanies)
            }
            
            currentOffset += newCompanies.count
            hasMoreData = newCompanies.count == pageSize
            
        } catch {
            errorMessage = handleError(error)
        }
        
        isLoading = false
    }
    
    private func fetchCompanies(query: String, offset: Int) async throws -> [CompanyCard] {
        let cacheKey = "\(query)_\(offset)"
        
        // Check cache first
        if let cachedData = getCachedData(for: cacheKey) {
            return cachedData
        }
        
        let companies: [CompanyCard]
        
        if query.isEmpty {
            companies = try await supabaseService.fetchAllCompanies(limit: pageSize, offset: offset)
        } else {
            companies = try await supabaseService.searchCompanies(offering: query, limit: pageSize, offset: offset)
        }
        
        // Cache the results
        setCache(companies, for: cacheKey)
        return companies
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
            return "Failed to load companies: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cache Management
    
    private func isCacheValid(for key: String) -> Bool {
        guard let timestamp = cacheTimestamps[key] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheExpirationTime
    }
    
    private func setCache(_ data: [CompanyCard], for key: String) {
        cache[key] = data
        cacheTimestamps[key] = Date()
    }
    
    private func getCachedData(for key: String) -> [CompanyCard]? {
        guard isCacheValid(for: key) else { return nil }
        return cache[key]
    }
    
    private func clearCache() {
        cache.removeAll()
        cacheTimestamps.removeAll()
    }
}

// MARK: - Company Card Model
struct CompanyCard: Identifiable, Codable, Sendable {
    let id: String
    let companyName: String
    let logoUrl: String?
    let rating: Double?
    let city: String?
    let previewImages: [String]
    let hourlyRate: Double?
    let description: String?
    let serviceTypes: [String]?
    let email: String?
    let phone: String?
    let verified: Bool
    let reviews: Int?
    let createdAt: String?
    let updatedAt: String?
    
    init(
        id: String,
        companyName: String,
        logoUrl: String? = nil,
        rating: Double? = nil,
        city: String? = nil,
        previewImages: [String] = [],
        hourlyRate: Double? = nil,
        description: String? = nil,
        serviceTypes: [String]? = nil,
        email: String? = nil,
        phone: String? = nil,
        verified: Bool = false,
        reviews: Int? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.companyName = companyName
        self.logoUrl = logoUrl
        self.rating = rating
        self.city = city
        self.previewImages = previewImages
        self.hourlyRate = hourlyRate
        self.description = description
        self.serviceTypes = serviceTypes
        self.email = email
        self.phone = phone
        self.verified = verified
        self.reviews = reviews
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Service Card Model
struct ServiceCard: Identifiable, Codable, Sendable {
    let id: String
    let serviceName: String
    let serviceType: String
    let price: Double?
    let pricePerHour: Double?
    let currency: String?
    let rating: Double?
    let city: String?
    let description: String?
    let specializations: [String]?
    let equipmentIncluded: [String]?
    let images: [String]?
    let isActive: Bool
    let totalBookings: Int?
    let providerId: String?
    
    init(
        id: String,
        serviceName: String,
        serviceType: String,
        price: Double? = nil,
        pricePerHour: Double? = nil,
        currency: String? = nil,
        rating: Double? = nil,
        city: String? = nil,
        description: String? = nil,
        specializations: [String]? = nil,
        equipmentIncluded: [String]? = nil,
        images: [String]? = nil,
        isActive: Bool = true,
        totalBookings: Int? = nil,
        providerId: String? = nil
    ) {
        self.id = id
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.price = price
        self.pricePerHour = pricePerHour
        self.currency = currency
        self.rating = rating
        self.city = city
        self.description = description
        self.specializations = specializations
        self.equipmentIncluded = equipmentIncluded
        self.images = images
        self.isActive = isActive
        self.totalBookings = totalBookings
        self.providerId = providerId
    }
}
