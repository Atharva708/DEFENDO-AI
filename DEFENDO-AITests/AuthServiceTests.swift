//
//  AuthServiceTests.swift
//  DEFENDO-AITests
//
//  Unit tests for AuthService
//

import XCTest
import Combine
@testable import DEFENDO_AI

final class AuthServiceTests: XCTestCase {
    var authService: AuthService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        authService = AuthService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        authService = nil
        cancellables = nil
        // Clean up keychain
        KeychainManager.shared.deleteAllSecureData()
    }
    
    func testInitialState() {
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isLoading)
        XCTAssertNil(authService.authError)
        XCTAssertNil(authService.authSuccess)
    }
    
    func testSignUpValidation() {
        let expectation = XCTestExpectation(description: "Sign up validation")
        
        // Test with invalid email
        Task {
            await authService.signUp(email: "invalid-email", password: "password123", name: "Test User", phone: "1234567890")
            
            DispatchQueue.main.async {
                XCTAssertNotNil(self.authService.authError)
                XCTAssertFalse(self.authService.isAuthenticated)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testClearMessages() {
        authService.authError = "Test error"
        authService.authSuccess = "Test success"
        
        authService.clearMessages()
        
        XCTAssertNil(authService.authError)
        XCTAssertNil(authService.authSuccess)
    }
    
    func testKeychainIntegration() {
        let testToken = "test_auth_token_123"
        
        // Save token
        let saveResult = KeychainManager.shared.saveAuthToken(testToken)
        XCTAssertTrue(saveResult)
        
        // Retrieve token
        let retrievedToken = KeychainManager.shared.getAuthToken()
        XCTAssertEqual(retrievedToken, testToken)
        
        // Delete token
        let deleteResult = KeychainManager.shared.deleteAuthToken()
        XCTAssertTrue(deleteResult)
        
        // Verify deletion
        let deletedToken = KeychainManager.shared.getAuthToken()
        XCTAssertNil(deletedToken)
    }
}
