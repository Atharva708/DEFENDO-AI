//
//  KeychainManager.swift
//  DEFENDO-AI
//
//  Secure storage manager using Keychain Services
//

import Foundation
import Security

class KeychainManager {
    
    // MARK: - Singleton
    static let shared = KeychainManager()
    private init() {}
    
    // MARK: - Keys
    private enum Keys {
        static let authToken = "auth_token"
        static let refreshToken = "refresh_token"
        static let userCredentials = "user_credentials"
        static let emergencyContacts = "emergency_contacts_secure"
    }
    
    // MARK: - Service Name
    private let service = AppConfig.bundleIdentifier
    
    // MARK: - Public Methods
    
    func saveAuthToken(_ token: String) -> Bool {
        return save(key: Keys.authToken, data: token.data(using: .utf8) ?? Data())
    }
    
    func getAuthToken() -> String? {
        guard let data = load(key: Keys.authToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func saveRefreshToken(_ token: String) -> Bool {
        return save(key: Keys.refreshToken, data: token.data(using: .utf8) ?? Data())
    }
    
    func getRefreshToken() -> String? {
        guard let data = load(key: Keys.refreshToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func saveUserCredentials(_ credentials: [String: Any]) -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: credentials)
            return save(key: Keys.userCredentials, data: data)
        } catch {
            print("Failed to serialize user credentials: \(error)")
            return false
        }
    }
    
    func getUserCredentials() -> [String: Any]? {
        guard let data = load(key: Keys.userCredentials) else { return nil }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("Failed to deserialize user credentials: \(error)")
            return nil
        }
    }
    
    func saveEmergencyContacts<T: Codable>(_ contacts: T) -> Bool {
        do {
            let data = try JSONEncoder().encode(contacts)
            return save(key: Keys.emergencyContacts, data: data)
        } catch {
            print("Failed to encode emergency contacts: \(error)")
            return false
        }
    }
    
    func getEmergencyContacts<T: Codable>(_ type: T.Type) -> T? {
        guard let data = load(key: Keys.emergencyContacts) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode emergency contacts: \(error)")
            return nil
        }
    }
    
    func deleteAuthToken() -> Bool {
        return delete(key: Keys.authToken)
    }
    
    func deleteRefreshToken() -> Bool {
        return delete(key: Keys.refreshToken)
    }
    
    func deleteUserCredentials() -> Bool {
        return delete(key: Keys.userCredentials)
    }
    
    func deleteAllSecureData() {
        _ = deleteAuthToken()
        _ = deleteRefreshToken()
        _ = deleteUserCredentials()
        _ = delete(key: Keys.emergencyContacts)
    }
    
    // MARK: - Private Methods
    
    private func save(key: String, data: Data) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            print("Keychain save failed with status: \(status)")
            return false
        }
    }
    
    private func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject? = nil
        
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as! Data?
        } else {
            if status != errSecItemNotFound {
                print("Keychain load failed with status: \(status)")
            }
            return nil
        }
    }
    
    private func delete(key: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            print("Keychain delete failed with status: \(status)")
            return false
        }
    }
}

// MARK: - Keychain Error Handling
extension KeychainManager {
    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
        
        var localizedDescription: String {
            switch self {
            case .noPassword:
                return "No password found in keychain"
            case .unexpectedPasswordData:
                return "Unexpected password data found in keychain"
            case .unhandledError(let status):
                return "Keychain error with status: \(status)"
            }
        }
    }
}
