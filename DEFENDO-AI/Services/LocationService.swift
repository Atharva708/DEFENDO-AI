//
//  LocationService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var locationError: String?
    @Published var isTrackingLocation = false
    @Published var lastKnownAddress: String?
    @Published var locationHistory: [CLLocation] = []
    @Published var safetyZones: [SafetyZone] = []
    @Published var nearbyIncidents: [IncidentReport] = []
    
    // Location tracking settings
    private let maxLocationHistory = 100
    private let locationUpdateInterval: TimeInterval = 30 // 30 seconds
    private var locationTimer: Timer?
    
    override init() {
        super.init()
        setupLocationManager()
        loadSafetyZones()
        startLocationTimer()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func startLocationTimer() {
        locationTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateLocationIfNeeded()
        }
    }
    
    private func updateLocationIfNeeded() {
        guard isLocationEnabled && isTrackingLocation else { return }
        locationManager.startUpdatingLocation()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
        isLocationEnabled = true
        isTrackingLocation = true
        
        // Start background location updates if authorized
        if authorizationStatus == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        isLocationEnabled = false
        isTrackingLocation = false
    }
    
    func toggleLocationTracking() {
        if isTrackingLocation {
            stopLocationTracking()
        } else {
            startLocationTracking()
        }
    }
    
    func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    func getLocationString() -> String {
        guard let location = currentLocation else {
            return "Location unavailable"
        }
        
        return "\(location.coordinate.latitude), \(location.coordinate.longitude)"
    }
    
    func getAddressFromLocation(completion: @escaping (String?) -> Void) {
        guard let location = currentLocation else {
            completion(nil)
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Geocoding error: \(error)")
                    completion(nil)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    completion(nil)
                    return
                }
                
                let address = [
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.locality,
                    placemark.administrativeArea
                ].compactMap { $0 }.joined(separator: ", ")
                
                if !address.isEmpty {
                    self?.lastKnownAddress = address
                }
                
                completion(address.isEmpty ? nil : address)
            }
        }
    }
    
    func calculateDistance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    func isWithinRadius(of coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) -> Bool {
        guard let distance = calculateDistance(to: coordinate) else { return false }
        return distance <= radius
    }
    
    // MARK: - Safety Zone Management
    private func loadSafetyZones() {
        // Load predefined safety zones (in a real app, this would come from an API)
        safetyZones = [
            SafetyZone(id: "1", name: "Downtown Business District", color: .green, riskLevel: 1, description: "Low risk area with high police presence"),
            SafetyZone(id: "2", name: "University Campus", color: .green, riskLevel: 1, description: "Safe campus environment"),
            SafetyZone(id: "3", name: "Industrial Area", color: .yellow, riskLevel: 3, description: "Moderate risk, limited lighting"),
            SafetyZone(id: "4", name: "Park Area", color: .yellow, riskLevel: 2, description: "Moderate risk during late hours"),
            SafetyZone(id: "5", name: "High Crime Zone", color: .red, riskLevel: 5, description: "High risk area, avoid if possible")
        ]
    }
    
    func getCurrentSafetyZone() -> SafetyZone? {
        guard let location = currentLocation else { return nil }
        
        // In a real app, this would check against actual zone boundaries
        // For now, we'll return a zone based on time and location
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 22 || hour <= 6 {
            return safetyZones.first { $0.color == .red }
        } else if hour >= 18 || hour <= 8 {
            return safetyZones.first { $0.color == .yellow }
        } else {
            return safetyZones.first { $0.color == .green }
        }
    }
    
    func getSafetyScore() -> Int {
        guard let zone = getCurrentSafetyZone() else { return 50 }
        
        switch zone.color {
        case .green:
            return 85
        case .yellow:
            return 65
        case .red:
            return 35
        }
    }
    
    // MARK: - Location History
    private func addToLocationHistory(_ location: CLLocation) {
        locationHistory.append(location)
        
        // Keep only the last maxLocationHistory locations
        if locationHistory.count > maxLocationHistory {
            locationHistory.removeFirst(locationHistory.count - maxLocationHistory)
        }
    }
    
    func getLocationHistory() -> [CLLocation] {
        return locationHistory
    }
    
    func clearLocationHistory() {
        locationHistory.removeAll()
    }
    
    // MARK: - Emergency Location Sharing
    func getEmergencyLocationData() -> [String: Any] {
        guard let location = currentLocation else {
            return [:]
        }
        
        return [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": location.timestamp.timeIntervalSince1970,
            "address": lastKnownAddress ?? "Unknown location",
            "accuracy": location.horizontalAccuracy,
            "speed": location.speed,
            "heading": location.course
        ]
    }
    
    // MARK: - Nearby Incidents
    func fetchNearbyIncidents(radius: CLLocationDistance = 1000) {
        guard let location = currentLocation else { return }
        
        // In a real app, this would fetch from an API
        // For now, we'll create mock incidents
        nearbyIncidents = [
            IncidentReport(
                id: "1",
                reporterId: "user1",
                incidentType: .suspicious,
                description: "Suspicious activity reported",
                location: "Near Main St & 5th Ave",
                timestamp: Date().addingTimeInterval(-3600),
                status: .investigating,
                attachments: []
            ),
            IncidentReport(
                id: "2",
                reporterId: "user2",
                incidentType: .theft,
                description: "Vehicle break-in reported",
                location: "Parking lot on Oak St",
                timestamp: Date().addingTimeInterval(-7200),
                status: .resolved,
                attachments: []
            )
        ]
    }
    
    // MARK: - Geofencing
    func startGeofencing(for locations: [CLLocationCoordinate2D], radius: CLLocationDistance = 100) {
        guard authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        for coordinate in locations {
            let region = CLCircularRegion(
                center: coordinate,
                radius: radius,
                identifier: "geofence_\(coordinate.latitude)_\(coordinate.longitude)"
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager.startMonitoring(for: region)
        }
    }
    
    func stopGeofencing() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.locationError = nil
            
            // Add to location history
            self.addToLocationHistory(location)
            
            // Update address
            self.getAddressFromLocation { _ in }
            
            // Fetch nearby incidents periodically
            if self.locationHistory.count % 10 == 0 {
                self.fetchNearbyIncidents()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
            print("Location error: \(error)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
            
            if self.isLocationEnabled {
                self.startLocationTracking()
            } else {
                self.stopLocationTracking()
            }
        }
    }
    
    // MARK: - Geofencing Delegate Methods
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered geofence: \(region.identifier)")
        // Handle entering a geofence (e.g., send notification)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited geofence: \(region.identifier)")
        // Handle exiting a geofence (e.g., send notification)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofencing monitoring failed: \(error)")
    }
}

