//
//  SupabaseClient.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import Foundation
import Supabase

// MARK: - Secure Supabase Client
class SupabaseManager {
    static let shared = SupabaseManager()
    
    private var configuredURL: URL?
    private var configuredAnonKey: String = ""
    
    private var _client: SupabaseClient?
    
    var client: SupabaseClient {
        if let existing = _client { return existing }
        // Determine URL/key from configured values or AppConfig
        let urlString = configuredURL?.absoluteString ?? AppConfig.Supabase.url
        let keyString = !configuredAnonKey.isEmpty ? configuredAnonKey : AppConfig.Supabase.anonKey
        guard let url = URL(string: urlString), !keyString.isEmpty else {
            // Return a placeholder client that will cause clear error downstream
            preconditionFailure("Supabase configuration is missing. Provide SUPABASE_URL/ANON_KEY in Info.plist or call SupabaseManager.shared.configure(url:key:)")
        }
        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(schema: "public"),
            auth: SupabaseClientOptions.AuthOptions(autoRefreshToken: true),
            global: SupabaseClientOptions.GlobalOptions(headers: [
                "x-client-info": "defendo-ai-ios/\(AppConfig.appVersion)"
            ])
        )
        let created = SupabaseClient(supabaseURL: url, supabaseKey: keyString, options: options)
        _client = created
        return created
    }
    
    func configure(url: String, key: String) {
        self.configuredURL = URL(string: url)
        self.configuredAnonKey = key
        self._client = nil
    }
    
    private init() {}
}

// Global client instance for backward compatibility
let client = SupabaseManager.shared.client
