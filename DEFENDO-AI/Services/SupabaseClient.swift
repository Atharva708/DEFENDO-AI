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
    
    lazy var client: SupabaseClient = {
        guard let url = URL(string: AppConfig.Supabase.url),
              !AppConfig.Supabase.anonKey.isEmpty else {
            fatalError("Supabase configuration is missing. Please check your Info.plist configuration.")
        }

        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(schema: "public"),
            auth: SupabaseClientOptions.AuthOptions(
                autoRefreshToken: true
            ),
            global: SupabaseClientOptions.GlobalOptions(headers: [
                "x-client-info": "defendo-ai-ios/\(AppConfig.appVersion)"
            ])
        )
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: AppConfig.Supabase.anonKey,
            options: options
        )
    }()
    
    private init() {}
}

// Global client instance for backward compatibility
let client = SupabaseManager.shared.client
