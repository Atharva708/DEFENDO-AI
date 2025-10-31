import Foundation

/// Utility for accessing values from the app's Info.plist
struct PlistInfoHelper {
    /// Fetches a string value for the given key in Info.plist
    static func string(forKey key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
    
    /// Returns the location usage description for "When In Use".
    static var locationWhenInUseUsageDescription: String? {
        string(forKey: "NSLocationWhenInUseUsageDescription")
    }
    
    /// Returns the location usage description for "Always and When In Use".
    static var locationAlwaysAndWhenInUseUsageDescription: String? {
        string(forKey: "NSLocationAlwaysAndWhenInUseUsageDescription")
    }
}
