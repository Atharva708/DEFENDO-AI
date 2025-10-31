//
//  SupabaseNetworkHelper.swift
//  DEFENDO-AI
//
//  Utilities for robust Supabase REST API access & safe resource loading
//

import Foundation
import UIKit
import Supabase

// MARK: - Supabase REST API Helper

struct SupabaseREST {
    /// Builds the REST endpoint for a given table
    static func tableURL(_ table: String) throws -> URL {
        guard !AppConfig.Supabase.url.isEmpty,
              let base = URL(string: AppConfig.Supabase.url) else {
            throw NetworkError.invalidResponse
        }
        return base.appendingPathComponent("rest/v1/")
                   .appendingPathComponent(table)
    }

    /// Returns REST headers for Supabase with user JWT for RLS
    static func authHeaders(userAccessToken: String) -> [String: String] {
        [
            "apikey": AppConfig.Supabase.anonKey,
            "Authorization": "Bearer \(userAccessToken)",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    /// POST a row (or any Codable payload) to a Supabase table using the logged-in user's token
    static func postRow<T: Codable>(to table: String, object: T, timeout: TimeInterval = 10.0) async throws -> Data {
        let url = try tableURL(table)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Acquire current user's access token for RLS
        let session = try await client.auth.session
        request.allHTTPHeaderFields = authHeaders(userAccessToken: session.accessToken)

        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = try JSONEncoder().encode([object]) // Supabase expects array for bulk insert

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

