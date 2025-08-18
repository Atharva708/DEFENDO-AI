//
//  MapKitService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

class MapKitService: NSObject, ObservableObject {
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var userLocation: CLLocation?
    @Published var safetyZones: [SafetyZoneAnnotation] = []
    @Published var nearbyIncidents: [IncidentAnnotation] = []
    @Published var emergencyContacts: [EmergencyContactAnnotation] = []
    @Published var securityProviders: [SecurityProviderAnnotation] = []
    @Published var isTrackingUser = false
    @Published var mapType: MKMapType = .standard
    @Published var showTraffic = false
    @Published var showBuildings = true
    @Published var showPointsOfInterest = true
    @Published var selectedAnnotation: MKAnnotation?
    @Published var routeToDestination: MKRoute?
    @Published var isRouting = false
    
    private var locationManager: CLLocationManager
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
        loadSafetyZones()
        setupMapDefaults()
    }
    
    // MARK: - Location Manager Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func setupMapDefaults() {
        // Set default map appearance
        mapType = .standard
        showTraffic = false
        showBuildings = true
        showPointsOfInterest = true
    }
    
    // MARK: - Location Tracking
    func startLocationTracking() {
        guard CLLocationManager.locationServicesEnabled() else {
            requestLocationPermission()
            return
        }
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            isTrackingUser = true
        case .notDetermined:
            requestLocationPermission()
        case .denied, .restricted:
            print("Location access denied")
        @unknown default:
            break
        }
    }
    
    func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
        isTrackingUser = false
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Map Region Management
    func centerOnUserLocation() {
        guard let location = userLocation else { return }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            mapRegion.center = location.coordinate
            mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }
    
    func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D, zoomLevel: Double = 0.01) {
        withAnimation(.easeInOut(duration: 1.0)) {
            mapRegion.center = coordinate
            mapRegion.span = MKCoordinateSpan(latitudeDelta: zoomLevel, longitudeDelta: zoomLevel)
        }
    }
    
    func fitAllAnnotations() {
        var annotations: [MKAnnotation] = []
        
        if let userLocation = userLocation {
            let userAnnotation = MKPointAnnotation()
            userAnnotation.coordinate = userLocation.coordinate
            userAnnotation.title = "Your Location"
            annotations.append(userAnnotation)
        }
        
        annotations.append(contentsOf: safetyZones)
        annotations.append(contentsOf: nearbyIncidents)
        annotations.append(contentsOf: emergencyContacts)
        annotations.append(contentsOf: securityProviders)
        
        guard !annotations.isEmpty else { return }
        
        let region = MKCoordinateRegion(coordinates: annotations.map { $0.coordinate })
        withAnimation(.easeInOut(duration: 1.0)) {
            mapRegion = region
        }
    }
    
    // MARK: - Safety Zones
    private func loadSafetyZones() {
        // Load predefined safety zones
        let zones = [
            SafetyZoneAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Downtown Business District",
                subtitle: "Low risk area with high police presence",
                color: .green,
                riskLevel: 1
            ),
            SafetyZoneAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                title: "University Campus",
                subtitle: "Safe campus environment",
                color: .green,
                riskLevel: 1
            ),
            SafetyZoneAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294),
                title: "Industrial Area",
                subtitle: "Moderate risk, limited lighting",
                color: .yellow,
                riskLevel: 3
            ),
            SafetyZoneAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4394),
                title: "High Crime Zone",
                subtitle: "High risk area, avoid if possible",
                color: .red,
                riskLevel: 5
            )
        ]
        
        DispatchQueue.main.async {
            self.safetyZones = zones
        }
    }
    
    func getCurrentSafetyZone() -> SafetyZoneAnnotation? {
        guard let userLocation = userLocation else { return nil }
        
        return safetyZones.first { zone in
            let zoneLocation = CLLocation(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude)
            let distance = userLocation.distance(from: zoneLocation)
            return distance <= 500 // 500 meters radius
        }
    }
    
    // MARK: - Incident Management
    func loadNearbyIncidents(radius: CLLocationDistance = 1000) {
        guard userLocation != nil else { return }
        
        // Simulate loading nearby incidents
        let incidents = [
            IncidentAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Suspicious Activity",
                subtitle: "Reported 1 hour ago",
                type: IncidentType.suspicious,
                severity: SeverityLevel.medium
            ),
            IncidentAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                title: "Vehicle Break-in",
                subtitle: "Reported 2 hours ago",
                type: IncidentType.theft,
                severity: SeverityLevel.high
            )
        ]
        
        DispatchQueue.main.async {
            self.nearbyIncidents = incidents
        }
    }
    
    // MARK: - Emergency Contacts
    func loadEmergencyContacts() {
        // Load user's emergency contacts on map
        let contacts = [
            EmergencyContactAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Sarah Johnson",
                subtitle: "Spouse - 2.3 km away",
                phone: "+1 (555) 987-6543",
                relationship: "Spouse"
            ),
            EmergencyContactAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                title: "Mike Smith",
                subtitle: "Friend - 1.8 km away",
                phone: "+1 (555) 456-7890",
                relationship: "Friend"
            )
        ]
        
        DispatchQueue.main.async {
            self.emergencyContacts = contacts
        }
    }
    
    // MARK: - Security Providers
    func loadSecurityProviders() {
        // Load nearby security providers
        let providers = [
            SecurityProviderAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Elite Security Services",
                subtitle: "Available - 4.2★ rating",
                serviceType: .securityGuard,
                isAvailable: true,
                rating: 4.2
            ),
            SecurityProviderAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                title: "SkyWatch Drones",
                subtitle: "Available - 4.5★ rating",
                serviceType: .dronePatrol,
                isAvailable: true,
                rating: 4.5
            )
        ]
        
        DispatchQueue.main.async {
            self.securityProviders = providers
        }
    }
    
    // MARK: - Routing
    func calculateRoute(to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile) {
        guard let userLocation = userLocation else { return }
        
        isRouting = true
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isRouting = false
                
                if let error = error {
                    print("Routing error: \(error)")
                    return
                }
                
                if let route = response?.routes.first {
                    self?.routeToDestination = route
                }
            }
        }
    }
    
    // MARK: - Map Controls
    func toggleMapType() {
        switch mapType {
        case .standard:
            mapType = .satellite
        case .satellite:
            mapType = .hybrid
        case .hybrid:
            mapType = .standard
        case .satelliteFlyover:
            mapType = .standard
        case .hybridFlyover:
            mapType = .standard
        case .mutedStandard:
            mapType = .standard
        @unknown default:
            mapType = .standard
        }
    }
    
    func toggleTraffic() {
        showTraffic.toggle()
    }
    
    func toggleBuildings() {
        showBuildings.toggle()
    }
    
    func togglePointsOfInterest() {
        showPointsOfInterest.toggle()
    }
    
    // MARK: - Search
    func searchNearbyPlaces(query: String, completion: @escaping ([MKMapItem]) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        if let userLocation = userLocation {
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Search error: \(error)")
                    completion([])
                    return
                }
                
                completion(response?.mapItems ?? [])
            }
        }
    }
    
    // MARK: - Geocoding
    func getAddressFromCoordinate(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
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
                
                completion(address.isEmpty ? nil : address)
            }
        }
    }
    
    func getCoordinateFromAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(address) { placemarks, error in
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
                
                completion(placemark.location?.coordinate)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension MapKitService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location
            
            // Update map region if tracking user
            if self.isTrackingUser {
                self.centerOnUserLocation()
            }
            
            // Load nearby data
            self.loadNearbyIncidents()
            self.loadSecurityProviders()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationTracking()
            case .denied, .restricted:
                self.stopLocationTracking()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}



// MARK: - Custom Annotations
class SafetyZoneAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let color: UIColor
    let riskLevel: Int
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, color: UIColor, riskLevel: Int) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.riskLevel = riskLevel
        super.init()
    }
}

class IncidentAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: IncidentType
    let severity: SeverityLevel
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, type: IncidentType, severity: SeverityLevel) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.severity = severity
        super.init()
    }
}

class EmergencyContactAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let phone: String
    let relationship: String
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, phone: String, relationship: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.phone = phone
        self.relationship = relationship
        super.init()
    }
}

class SecurityProviderAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let serviceType: ServiceType
    let isAvailable: Bool
    let rating: Double
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, serviceType: ServiceType, isAvailable: Bool, rating: Double) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.serviceType = serviceType
        self.isAvailable = isAvailable
        self.rating = rating
        super.init()
    }
}

// MARK: - Helper Extensions
extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self.init()
            return
        }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )
        
        self.init(center: center, span: span)
    }
}
