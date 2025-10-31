//
//  LocationServiceTests.swift
//  DEFENDO-AITests
//
//  Unit tests for LocationService
//

import XCTest
import CoreLocation
import Combine
@testable import DEFENDO_AI

final class LocationServiceTests: XCTestCase {
    var locationService: LocationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        locationService = LocationService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        locationService = nil
        cancellables = nil
    }
    
    func testInitialState() {
        XCTAssertNil(locationService.currentLocation)
        XCTAssertEqual(locationService.authorizationStatus, .notDetermined)
        XCTAssertFalse(locationService.isLocationEnabled)
        XCTAssertNil(locationService.locationError)
        XCTAssertFalse(locationService.isTrackingLocation)
        XCTAssertNil(locationService.lastKnownAddress)
        XCTAssertTrue(locationService.locationHistory.isEmpty)
        XCTAssertFalse(locationService.safetyZones.isEmpty) // Should have mock safety zones
    }
    
    func testSafetyZones() {
        let safetyZones = locationService.safetyZones
        XCTAssertFalse(safetyZones.isEmpty)
        
        // Test that we have different risk levels
        let riskLevels = Set(safetyZones.map { $0.riskLevel })
        XCTAssertTrue(riskLevels.count > 1)
        
        // Test that we have different colors
        let colors = Set(safetyZones.map { $0.color })
        XCTAssertTrue(colors.count > 1)
    }
    
    func testSafetyScore() {
        let safetyScore = locationService.getSafetyScore()
        XCTAssertTrue(safetyScore >= 0 && safetyScore <= 100)
    }
    
    func testLocationString() {
        // Test with no location
        let initialLocationString = locationService.getLocationString()
        XCTAssertEqual(initialLocationString, "Location unavailable")
        
        // Test with mock location
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationService.currentLocation = mockLocation
        
        let locationString = locationService.getLocationString()
        XCTAssertTrue(locationString.contains("37.7749"))
        XCTAssertTrue(locationString.contains("-122.4194"))
    }
    
    func testDistanceCalculation() {
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationService.currentLocation = mockLocation
        
        let targetCoordinate = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        let distance = locationService.calculateDistance(to: targetCoordinate)
        
        XCTAssertNotNil(distance)
        XCTAssertTrue(distance! > 0)
    }
    
    func testWithinRadius() {
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationService.currentLocation = mockLocation
        
        let nearbyCoordinate = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
        let farCoordinate = CLLocationCoordinate2D(latitude: 38.0000, longitude: -123.0000)
        
        XCTAssertTrue(locationService.isWithinRadius(of: nearbyCoordinate, radius: 1000))
        XCTAssertFalse(locationService.isWithinRadius(of: farCoordinate, radius: 1000))
    }
    
    func testLocationHistory() {
        let mockLocation1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let mockLocation2 = CLLocation(latitude: 37.7750, longitude: -122.4195)
        
        // Simulate adding locations to history
        locationService.currentLocation = mockLocation1
        // Simulate the private method call
        locationService.locationHistory.append(mockLocation1)
        
        locationService.currentLocation = mockLocation2
        locationService.locationHistory.append(mockLocation2)
        
        let history = locationService.getLocationHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.last?.coordinate.latitude, mockLocation2.coordinate.latitude)
        
        locationService.clearLocationHistory()
        XCTAssertTrue(locationService.getLocationHistory().isEmpty)
    }
    
    func testEmergencyLocationData() {
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationService.currentLocation = mockLocation
        locationService.lastKnownAddress = "Test Address"
        
        let emergencyData = locationService.getEmergencyLocationData()
        
        XCTAssertEqual(emergencyData["latitude"] as? Double, 37.7749)
        XCTAssertEqual(emergencyData["longitude"] as? Double, -122.4194)
        XCTAssertEqual(emergencyData["address"] as? String, "Test Address")
        XCTAssertNotNil(emergencyData["timestamp"])
        XCTAssertNotNil(emergencyData["accuracy"])
    }
}
