//
//  SupabaseNetworkHelper.swift
//  DEFENDO-AI
//
//  Utilities for robust Supabase REST API access & safe resource loading
//

import Foundation
import UIKit

// MARK: - Supabase REST API Helper

struct SupabaseREST {
    // Set these with your actual project values
    static let projectURL = URL(string: "https://YOUR-SUPABASE-PROJECT.supabase.co/rest/v1/bookings")! // <--- Replace!
    static let apiKey = "YOUR_SUPABASE_API_KEY" // <--- Replace with your key

    /// Returns default headers for Supabase REST API requests
    static func defaultHeaders() -> [String: String] {
        [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    /// POST a booking (or any Codable payload) to Supabase
    static func postBooking<T: Codable>(_ object: T, timeout: TimeInterval = 10.0) async throws -> Data {
        var request = URLRequest(url: projectURL)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = defaultHeaders()
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = try JSONEncoder().encode([object]) // Supabase expects array for bulk insert

        // Use non-main queue for request
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error as? URLError {
                    if error.code == .notConnectedToInternet {
                        continuation.resume(throwing: NetworkError.noConnection)
                    } else if error.code == .timedOut {
                        continuation.resume(throwing: NetworkError.timeout)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: NetworkError.serverError(httpResponse.statusCode))
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }
                continuation.resume(returning: data)
            }.resume()
        }
    }
}

// MARK: - Error Types

// MARK: - Bundle File Loader

struct BundleResourceLoader {
    /// Safely locate and load a bundled resource file
    static func fileURL(for filename: String, withExtension ext: String) -> URL? {
        Bundle.main.url(forResource: filename, withExtension: ext)
    }

    /// Loads file as Data if present
    static func loadFileData(named filename: String, ext: String) throws -> Data {
        guard let url = fileURL(for: filename, withExtension: ext) else {
            throw NSError(domain: "BundleResourceLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "File \(filename).\(ext) not found in bundle."])
        }
        return try Data(contentsOf: url)
    }
}

// MARK: - Info.plist & Entitlements Checklist (Comments Only)

/*
INFO.PLIST:
- NSLocationWhenInUseUsageDescription (String)
- NSLocationAlwaysAndWhenInUseUsageDescription (String)
- NSLocationAlwaysUsageDescription (String, optional for background)
- NSAppTransportSecurity / NSAllowsArbitraryLoads = true (for Supabase if HTTPS is strict)
- Privacy - Camera Usage, Microphone Usage, Contacts Usage, etc. as needed
- UIBackgroundModes: ["location"] (for background location)
- Metal (if using Metal in your app: ensure View sizes are never zero)

ENTITLEMENTS:
- com.apple.developer.networking.wifi-info (if accessing WiFi info)
- com.apple.developer.location-services.background
- com.apple.developer.location-services (should be auto-added with location)
- App Sandbox: Outgoing Connections (for network)

// ----
// Metal Rendering Errors:
// Ensure your MTKView/Metal view always has a non-zero, valid size.
// Example fix (UIKit):
//   override func layoutSubviews() {
//     super.layoutSubviews()
//     metalView.drawableSize = bounds.size.width > 0 && bounds.size.height > 0 ? bounds.size : CGSize(width: 1, height: 1)
//   }

// SwiftUI: use .aspectRatio() or .frame(minWidth:1, minHeight:1) for Metal views

// LocationManager and Main Thread:
// Use delegate methods (locationManagerDidChangeAuthorization) to respond instantly.
// Never block the main thread for location requests.
// Always update UI state via DispatchQueue.main.async if called off main.
*/

