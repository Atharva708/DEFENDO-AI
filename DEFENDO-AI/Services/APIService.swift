//
//  APIService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import Foundation
import Combine
import CoreLocation
import UIKit

class APIService: ObservableObject {
    private let baseURL = AppConfig.API.baseURL
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.API.timeout
        config.timeoutIntervalForResource = AppConfig.API.timeout * 2
        return URLSession(configuration: config)
    }()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - SOS Emergency API
    func sendSOSAlert(userId: String, location: CLLocation, description: String?) -> AnyPublisher<SOSResponse, Error> {
        let endpoint = "\(baseURL)/sos/alert"
        
        let sosData = SOSAlertRequest(
            userId: userId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            description: description,
            timestamp: Date(),
            deviceInfo: getDeviceInfo()
        )
        
        return makeRequest(endpoint: endpoint, method: "POST", body: sosData)
    }
    
    func updateSOSStatus(alertId: String, status: SOSStatus) -> AnyPublisher<SOSResponse, Error> {
        let endpoint = "\(baseURL)/sos/alert/\(alertId)/status"
        
        let statusData = SOSStatusUpdate(status: status, timestamp: Date())
        
        return makeRequest(endpoint: endpoint, method: "PUT", body: statusData)
    }
    
    // MARK: - Police/Security Agency Integration
    func notifyPoliceDepartment(location: CLLocation, incidentType: String, description: String) -> AnyPublisher<PoliceResponse, Error> {
        let endpoint = "\(baseURL)/police/incident"
        
        let policeData = PoliceIncidentRequest(
            location: LocationData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            incidentType: incidentType,
            description: description,
            timestamp: Date(),
            priority: "HIGH"
        )
        
        return makeRequest(endpoint: endpoint, method: "POST", body: policeData)
    }
    
    func getNearbySecurityAgencies(location: CLLocation, radius: Double) -> AnyPublisher<[SecurityAgency], Error> {
        let endpoint = "\(baseURL)/agencies/nearby"
        let queryItems = [
            URLQueryItem(name: "lat", value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "lng", value: "\(location.coordinate.longitude)"),
            URLQueryItem(name: "radius", value: "\(radius)")
        ]
        
        return makeRequest(endpoint: endpoint, method: "GET", queryItems: queryItems)
    }
    
    // MARK: - Booking API
    func createBooking(booking: BookingRequest) -> AnyPublisher<BookingResponse, Error> {
        let endpoint = "\(baseURL)/bookings"
        return makeRequest(endpoint: endpoint, method: "POST", body: booking)
    }
    
    func getBookings(userId: String) -> AnyPublisher<[Booking], Error> {
        let endpoint = "\(baseURL)/bookings"
        let queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        return makeRequest(endpoint: endpoint, method: "GET", queryItems: queryItems)
    }
    
    func updateBookingStatus(bookingId: String, status: BookingStatus) -> AnyPublisher<BookingResponse, Error> {
        let endpoint = "\(baseURL)/bookings/\(bookingId)/status"
        let statusData = BookingStatusUpdate(status: status, timestamp: Date())
        
        return makeRequest(endpoint: endpoint, method: "PUT", body: statusData)
    }
    
    // MARK: - Provider API
    func getProviders(category: String, filters: ProviderFilters) -> AnyPublisher<[MarketplaceProvider], Error> {
        let endpoint = "\(baseURL)/providers"
        var queryItems = [URLQueryItem(name: "category", value: category)]
        
        if let minRating = filters.minRating {
            queryItems.append(URLQueryItem(name: "minRating", value: "\(minRating)"))
        }
        if let maxPrice = filters.maxPrice {
            queryItems.append(URLQueryItem(name: "maxPrice", value: "\(maxPrice)"))
        }
        if filters.verifiedOnly {
            queryItems.append(URLQueryItem(name: "verified", value: "true"))
        }
        
        return makeRequest(endpoint: endpoint, method: "GET", queryItems: queryItems)
    }
    
    // MARK: - Analytics API
    func sendAnalyticsEvent(event: AnalyticsEvent) -> AnyPublisher<AnalyticsResponse, Error> {
        let endpoint = "\(baseURL)/analytics/events"
        return makeRequest(endpoint: endpoint, method: "POST", body: event)
    }
    
    func getSafetyScore(location: CLLocation) -> AnyPublisher<SafetyScoreResponse, Error> {
        let endpoint = "\(baseURL)/safety/score"
        let queryItems = [
            URLQueryItem(name: "lat", value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "lng", value: "\(location.coordinate.longitude)")
        ]
        
        return makeRequest(endpoint: endpoint, method: "GET", queryItems: queryItems)
    }
    
    // MARK: - Generic Request Method
    private func makeRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<U, Error> {
        guard var urlComponents = URLComponents(string: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        if let queryItems = queryItems {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: APIError.encodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: U.self, decoder: JSONDecoder())
            .mapError { APIError.networkError($0) }
            .eraseToAnyPublisher()
    }

    // Overload for requests without a body (e.g., GET)
    private func makeRequest<U: Codable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<U, Error> {
        guard var urlComponents = URLComponents(string: endpoint) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        if let queryItems = queryItems { urlComponents.queryItems = queryItems }
        guard let url = urlComponents.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: U.self, decoder: JSONDecoder())
            .mapError { APIError.networkError($0) }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    private func getAuthToken() -> String {
        return KeychainManager.shared.getAuthToken() ?? ""
    }
    
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            platform: "iOS",
            version: UIDevice.current.systemVersion,
            model: UIDevice.current.model,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }
}

// MARK: - Data Models
struct SOSAlertRequest: Codable {
    let userId: String
    let latitude: Double
    let longitude: Double
    let description: String?
    let timestamp: Date
    let deviceInfo: DeviceInfo
}

struct SOSResponse: Codable {
    let alertId: String
    let status: String
    let estimatedResponseTime: Int
    let assignedAgency: String?
}

struct SOSStatusUpdate: Codable {
    let status: SOSStatus
    let timestamp: Date
}

struct PoliceIncidentRequest: Codable {
    let location: LocationData
    let incidentType: String
    let description: String
    let timestamp: Date
    let priority: String
}

struct PoliceResponse: Codable {
    let incidentId: String
    let status: String
    let estimatedArrival: Int
    let unitNumber: String?
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
}

struct SecurityAgency: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let distance: Double
    let responseTime: Int
    let contactNumber: String
}

struct BookingRequest: Codable {
    let userId: String
    let serviceType: String
    let providerId: String
    let date: Date
    let duration: Int
    let location: String
    let specialInstructions: String?
}

struct BookingResponse: Codable {
    let bookingId: String
    let status: String
    let totalPrice: Double
    let confirmationCode: String
}

struct BookingStatusUpdate: Codable {
    let status: BookingStatus
    let timestamp: Date
}

struct ProviderFilters: Codable {
    let minRating: Double?
    let maxPrice: Double?
    let verifiedOnly: Bool
    let tags: [String]?
}

struct AnalyticsEvent: Codable {
    let eventType: String
    let userId: String
    let timestamp: Date
    let metadata: [String: String]
}

struct AnalyticsResponse: Codable {
    let success: Bool
    let eventId: String
}

struct SafetyScoreResponse: Codable {
    let score: Int
    let riskLevel: String
    let recommendations: [String]
    let lastUpdated: Date
}

struct DeviceInfo: Codable {
    let platform: String
    let version: String
    let model: String
    let appVersion: String
}

struct APIErrorResponse: Codable {
    let message: String
    let code: String
}

// MARK: - Error Types
enum APIError: Error {
    case invalidURL
    case encodingError
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case notFound
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Failed to encode request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .notFound:
            return "Resource not found"
        }
    }
}
