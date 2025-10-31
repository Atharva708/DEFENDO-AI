//
//  ErrorHandling.swift
//  DEFENDO-AI
//
//  Centralized error handling and logging system
//

import Foundation
import UIKit

// MARK: - App Errors
enum AppError: Error {
    case network(NetworkError)
    case authentication(AuthError)
    case location(LocationError)
    case storage(StorageError)
    case permission(PermissionError)
    case validation(ValidationError)
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .authentication(let error):
            return error.localizedDescription
        case .location(let error):
            return error.localizedDescription
        case .storage(let error):
            return error.localizedDescription
        case .permission(let error):
            return error.localizedDescription
        case .validation(let error):
            return error.localizedDescription
        case .unknown(let message):
            return message
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .network:
            return "Please check your internet connection and try again."
        case .authentication:
            return "Authentication failed. Please check your credentials."
        case .location:
            return "Location services are required for this feature."
        case .storage:
            return "Failed to save data. Please try again."
        case .permission:
            return "Permission is required to use this feature."
        case .validation:
            return "Please check your input and try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Specific Error Types
enum NetworkError: Error {
    case noConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

enum AuthError: Error {
    case invalidCredentials
    case userNotFound
    case emailNotVerified
    case accountLocked
    case tokenExpired
    case invalidToken
    
    var localizedDescription: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User account not found"
        case .emailNotVerified:
            return "Please verify your email address"
        case .accountLocked:
            return "Account is temporarily locked"
        case .tokenExpired:
            return "Session expired. Please sign in again"
        case .invalidToken:
            return "Invalid authentication token"
        }
    }
}

enum LocationError: Error {
    case permissionDenied
    case serviceDisabled
    case locationUnavailable
    case accuracyTooLow
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .serviceDisabled:
            return "Location services disabled"
        case .locationUnavailable:
            return "Location temporarily unavailable"
        case .accuracyTooLow:
            return "Location accuracy too low"
        }
    }
}

enum StorageError: Error {
    case saveFailed
    case loadFailed
    case deleteFailed
    case corruptedData
    case insufficientSpace
    
    var localizedDescription: String {
        switch self {
        case .saveFailed:
            return "Failed to save data"
        case .loadFailed:
            return "Failed to load data"
        case .deleteFailed:
            return "Failed to delete data"
        case .corruptedData:
            return "Data is corrupted"
        case .insufficientSpace:
            return "Insufficient storage space"
        }
    }
}

enum PermissionError: Error {
    case camera
    case microphone
    case contacts
    case notifications
    case location
    
    var localizedDescription: String {
        switch self {
        case .camera:
            return "Camera permission required"
        case .microphone:
            return "Microphone permission required"
        case .contacts:
            return "Contacts permission required"
        case .notifications:
            return "Notification permission required"
        case .location:
            return "Location permission required"
        }
    }
}

enum ValidationError: Error {
    case invalidEmail
    case weakPassword
    case phoneNumberInvalid
    case nameRequired
    case fieldRequired(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .phoneNumberInvalid:
            return "Please enter a valid phone number"
        case .nameRequired:
            return "Name is required"
        case .fieldRequired(let field):
            return "\(field) is required"
        }
    }
}

// MARK: - Error Logger
class ErrorLogger {
    static let shared = ErrorLogger()
    private init() {}
    
    func log(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = """
        🚨 Error in \(fileName):\(function):\(line)
        Error: \(error.localizedDescription)
        Type: \(type(of: error))
        Time: \(Date().formatted())
        """
        
        if AppConfig.Features.enableDetailedLogging {
            print(logMessage)
        }
        
        // In production, send to crash reporting service
        if AppConfig.Features.enableCrashReporting {
            // TODO: Send to crash reporting service (Crashlytics, Sentry, etc.)
        }
    }
    
    func logCritical(_ error: Error, context: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let contextString = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        
        let logMessage = """
        🔥 CRITICAL ERROR in \(fileName):\(function):\(line)
        Error: \(error.localizedDescription)
        Type: \(type(of: error))
        Context: \(contextString)
        Time: \(Date().formatted())
        """
        
        print(logMessage)
        
        // Always send critical errors to crash reporting
        // TODO: Send to crash reporting service
    }
}

// MARK: - Error Handler
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showingError = false
    
    static let shared = ErrorHandler()
    private init() {}
    
    func handle(_ error: Error) {
        ErrorLogger.shared.log(error)
        
        DispatchQueue.main.async {
            if let appError = error as? AppError {
                self.currentError = appError
            } else {
                self.currentError = AppError.unknown(error.localizedDescription)
            }
            self.showingError = true
        }
    }
    
    func handleCritical(_ error: Error, context: [String: Any] = [:]) {
        ErrorLogger.shared.logCritical(error, context: context)
        
        DispatchQueue.main.async {
            if let appError = error as? AppError {
                self.currentError = appError
            } else {
                self.currentError = AppError.unknown(error.localizedDescription)
            }
            self.showingError = true
        }
    }
    
    func clearError() {
        currentError = nil
        showingError = false
    }
}

// MARK: - Result Extensions
extension Result {
    func handleError() {
        if case .failure(let error) = self {
            ErrorHandler.shared.handle(error)
        }
    }
}

// MARK: - Publisher Extensions
import Combine

extension Publisher {
    func handleErrors() -> AnyPublisher<Output, Never> {
        return self
            .catch { error -> Empty<Output, Never> in
                ErrorHandler.shared.handle(error)
                return Empty()
            }
            .eraseToAnyPublisher()
    }
}
