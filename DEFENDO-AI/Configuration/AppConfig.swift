//
//  AppConfig.swift
//  DEFENDO-AI
//
//  Configuration management for different environments
//

import Foundation

struct AppConfig {
    
    // MARK: - Environment
    enum Environment: String, CaseIterable {
        case development = "Development"
        case staging = "Staging"
        case production = "Production"
    }
    
    // MARK: - Current Environment
    static let current: Environment = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()
    
    // MARK: - Supabase Configuration
    struct Supabase {
        static var url: String {
            switch current {
            case .development:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL_DEV") as? String ?? ""
            case .staging:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL_STAGING") as? String ?? ""
            case .production:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL_PROD") as? String ?? ""
            }
        }
        
        static var anonKey: String {
            switch current {
            case .development:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY_DEV") as? String ?? ""
            case .staging:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY_STAGING") as? String ?? ""
            case .production:
                return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY_PROD") as? String ?? ""
            }
        }
    }
    
    // MARK: - API Configuration
    struct API {
        static var baseURL: String {
            switch current {
            case .development:
                return "https://dev-api.securenow.com/v1"
            case .staging:
                return "https://staging-api.securenow.com/v1"
            case .production:
                return "https://api.securenow.com/v1"
            }
        }
        
        static var timeout: TimeInterval {
            return 30.0
        }
    }
    
    // MARK: - Feature Flags
    struct Features {
        static var enableAnalytics: Bool {
            switch current {
            case .development:
                return false
            case .staging, .production:
                return true
            }
        }
        
        static var enableCrashReporting: Bool {
            switch current {
            case .development:
                return false
            case .staging, .production:
                return true
            }
        }
        
        static var enableDetailedLogging: Bool {
            switch current {
            case .development, .staging:
                return true
            case .production:
                return false
            }
        }
    }
    
    // MARK: - App Information
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.securenow.defendo-ai"
    }
}
