//
//  ProfessionalMapView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import SwiftUI
import MapKit

struct ProfessionalMapView: View {
    @EnvironmentObject var mapKitService: MapKitService
    @EnvironmentObject var locationService: LocationService
    @State private var showingMapControls = false
    @State private var showingSearch = false
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedAnnotation: MKAnnotation?
    @State private var showingAnnotationDetail = false
    
    var body: some View {
        ZStack {
            // Main Map View
            MapViewRepresentable(
                region: $mapKitService.mapRegion,
                mapType: mapKitService.mapType,
                showTraffic: mapKitService.showTraffic,
                showBuildings: mapKitService.showBuildings,
                showPointsOfInterest: mapKitService.showPointsOfInterest,
                userLocation: mapKitService.userLocation,
                safetyZones: mapKitService.safetyZones,
                nearbyIncidents: mapKitService.nearbyIncidents,
                emergencyContacts: mapKitService.emergencyContacts,
                securityProviders: mapKitService.securityProviders,
                routeToDestination: mapKitService.routeToDestination,
                selectedAnnotation: $selectedAnnotation
            )
            .ignoresSafeArea()
            
            // Top Controls
            VStack {
                HStack {
                    // Location Button
                    Button(action: {
                        mapKitService.centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    
                    Spacer()
                    
                    // Search Button
                    Button(action: {
                        showingSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    
                    // Map Controls Button
                    Button(action: {
                        showingMapControls.toggle()
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom Info Panel
                if let currentZone = mapKitService.getCurrentSafetyZone() {
                    SafetyZoneInfoCard(zone: currentZone)
                        .padding()
                }
            }
        }
        .onAppear {
            mapKitService.startLocationTracking()
            mapKitService.loadEmergencyContacts()
        }
        .sheet(isPresented: $showingMapControls) {
            MapControlsView()
                .environmentObject(mapKitService)
        }
        .sheet(isPresented: $showingSearch) {
            MapSearchView(
                searchQuery: $searchQuery,
                searchResults: $searchResults,
                onSearch: performSearch,
                onSelectResult: selectSearchResult
            )
        }
        .sheet(isPresented: $showingAnnotationDetail) {
            if let annotation = selectedAnnotation {
                AnnotationDetailView(annotation: annotation)
            }
        }

    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        mapKitService.searchNearbyPlaces(query: searchQuery) { results in
            searchResults = results
        }
    }
    
    private func selectSearchResult(_ mapItem: MKMapItem) {
        mapKitService.centerOnCoordinate(mapItem.placemark.coordinate)
        showingSearch = false
    }
}

// MARK: - Map View Representable
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let mapType: MKMapType
    let showTraffic: Bool
    let showBuildings: Bool
    let showPointsOfInterest: Bool
    let userLocation: CLLocation?
    let safetyZones: [SafetyZoneAnnotation]
    let nearbyIncidents: [IncidentAnnotation]
    let emergencyContacts: [EmergencyContactAnnotation]
    let securityProviders: [SecurityProviderAnnotation]
    let routeToDestination: MKRoute?
    @Binding var selectedAnnotation: MKAnnotation?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = mapType
        mapView.showsTraffic = showTraffic
        mapView.showsBuildings = showBuildings
        mapView.showsPointsOfInterest = showPointsOfInterest
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map properties
        mapView.mapType = mapType
        mapView.showsTraffic = showTraffic
        mapView.showsBuildings = showBuildings
        mapView.showsPointsOfInterest = showPointsOfInterest
        
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Update annotations
        updateAnnotations(on: mapView)
        
        // Update route overlay
        updateRouteOverlay(on: mapView)
    }
    
    private func updateAnnotations(on mapView: MKMapView) {
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add safety zones
        mapView.addAnnotations(safetyZones)
        
        // Add nearby incidents
        mapView.addAnnotations(nearbyIncidents)
        
        // Add emergency contacts
        mapView.addAnnotations(emergencyContacts)
        
        // Add security providers
        mapView.addAnnotations(securityProviders)
    }
    
    private func updateRouteOverlay(on mapView: MKMapView) {
        // Remove existing route overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Add new route overlay
        if let route = routeToDestination {
            mapView.addOverlay(route.polyline, level: .aboveRoads)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // Use default user location view
            }
            
            // Safety Zone Annotation
            if let safetyZone = annotation as? SafetyZoneAnnotation {
                let identifier = "SafetyZone"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                
                annotationView?.markerTintColor = safetyZone.color
                annotationView?.glyphImage = UIImage(systemName: "shield.fill")
                annotationView?.canShowCallout = true
                
                return annotationView
            }
            
            // Incident Annotation
            if let incident = annotation as? IncidentAnnotation {
                let identifier = "Incident"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                
                annotationView?.markerTintColor = incident.severity.color
                annotationView?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                annotationView?.canShowCallout = true
                
                return annotationView
            }
            
            // Emergency Contact Annotation
            if let contact = annotation as? EmergencyContactAnnotation {
                let identifier = "EmergencyContact"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                
                annotationView?.markerTintColor = .red
                annotationView?.glyphImage = UIImage(systemName: "person.2.fill")
                annotationView?.canShowCallout = true
                
                return annotationView
            }
            
            // Security Provider Annotation
            if let provider = annotation as? SecurityProviderAnnotation {
                let identifier = "SecurityProvider"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                
                annotationView?.markerTintColor = provider.isAvailable ? .green : .gray
                annotationView?.glyphImage = UIImage(systemName: "person.badge.shield.checkmark.fill")
                annotationView?.canShowCallout = true
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            parent.selectedAnnotation = view.annotation
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            parent.selectedAnnotation = nil
        }
    }
}

// MARK: - Safety Zone Info Card
struct SafetyZoneInfoCard: View {
    let zone: SafetyZoneAnnotation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(Color(zone.color))
                
                Text(zone.title ?? "Safety Zone")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Risk Level \(zone.riskLevel)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(zone.color).opacity(0.2))
                    .foregroundColor(Color(zone.color))
                    .cornerRadius(8)
            }
            
            Text(zone.subtitle ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// MARK: - Map Controls View
struct MapControlsView: View {
    @EnvironmentObject var mapKitService: MapKitService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Map Type") {
                    HStack {
                        Text("Map Style")
                        Spacer()
                        Button(mapKitService.mapType.displayName) {
                            mapKitService.toggleMapType()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Map Features") {
                    Toggle("Show Traffic", isOn: $mapKitService.showTraffic)
                    Toggle("Show Buildings", isOn: $mapKitService.showBuildings)
                    Toggle("Show Points of Interest", isOn: $mapKitService.showPointsOfInterest)
                }
                
                Section("Location") {
                    HStack {
                        Text("Tracking Status")
                        Spacer()
                        Text(mapKitService.isTrackingUser ? "Active" : "Inactive")
                            .foregroundColor(mapKitService.isTrackingUser ? .green : .red)
                    }
                    
                    Button("Center on My Location") {
                        mapKitService.centerOnUserLocation()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Map Actions") {
                    Button("Fit All Annotations") {
                        mapKitService.fitAllAnnotations()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Map Controls")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// MARK: - Map Search View
struct MapSearchView: View {
    @Binding var searchQuery: String
    @Binding var searchResults: [MKMapItem]
    let onSearch: () -> Void
    let onSelectResult: (MKMapItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    TextField("Search places...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Search") {
                        onSearch()
                    }
                    .disabled(searchQuery.isEmpty)
                }
                .padding()
                
                // Search Results
                List(searchResults, id: \.self) { mapItem in
                    Button(action: {
                        onSelectResult(mapItem)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mapItem.name ?? "Unknown Location")
                                .font(.headline)
                            
                            Text(mapItem.placemark.title ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Search Places")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

// MARK: - Annotation Detail View
struct AnnotationDetailView: View {
    let annotation: MKAnnotation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: annotationIcon)
                    .font(.system(size: 60))
                    .foregroundColor(annotationColor)
                
                // Title
                Text(annotationTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Subtitle
                if let subtitleText = annotationSubtitle, !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button("Get Directions") {
                        // Handle directions
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    if let contact = annotation as? EmergencyContactAnnotation {
                        Button("Call \(contact.title ?? "Contact")") {
                            // Handle phone call
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Location Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
    
    // MARK: - Computed Properties
    
    private var annotationIcon: String {
        if annotation is SafetyZoneAnnotation {
            return "shield.fill"
        } else if annotation is IncidentAnnotation {
            return "exclamationmark.triangle.fill"
        } else if annotation is EmergencyContactAnnotation {
            return "person.2.fill"
        } else if annotation is SecurityProviderAnnotation {
            return "person.badge.shield.checkmark.fill"
        }
        return "mappin"
    }
    
    private var annotationColor: Color {
        if let safetyZone = annotation as? SafetyZoneAnnotation {
            return Color(safetyZone.color)
        } else if let incident = annotation as? IncidentAnnotation {
            return Color(incident.severity.color)
        } else if annotation is EmergencyContactAnnotation {
            return .red
        } else if let provider = annotation as? SecurityProviderAnnotation {
            return provider.isAvailable ? .green : .gray
        }
        return .blue
    }
    
    private var annotationTitle: String {
        // Safely flatten double optional
        (annotation.title ?? nil) ?? "Unknown Location"
    }
    
    private var annotationSubtitle: String? {
        // Safely flatten double optional
        (annotation.subtitle ?? nil)
    }
}


// MARK: - Extensions
extension MKMapType {
    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .satellite:
            return "Satellite"
        case .hybrid:
            return "Hybrid"
        case .satelliteFlyover:
            return "Satellite Flyover"
        case .hybridFlyover:
            return "Hybrid Flyover"
        case .mutedStandard:
            return "Muted Standard"
        @unknown default:
            return "Standard"
        }
    }
}



#Preview {
    ProfessionalMapView()
        .environmentObject(MapKitService())
        .environmentObject(LocationService())
}

