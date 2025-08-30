//
//  LiveLocationView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct LiveLocationView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mapKitService: MapKitService
    @State private var showingLocationHistory = false
    @State private var showingSafetyZones = false
    @State private var showingEmergencyContacts = false
    @State private var showingLocationSettings = false
    @State private var isSharingLocation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Live Location Status Card
                    LiveLocationStatusCard()
                    
                    // Current Location Details
                    CurrentLocationDetailsCard()
                    
                    // Safety Information
                    SafetyInformationCard()
                    
                    // Location Controls
                    LocationControlsCard()
                    
                    // Quick Actions
                    QuickActionsCard()
                    
                    // Location History Preview
                    LocationHistoryPreviewCard()
                }
                .padding()
            }
            .navigationTitle("Live Location")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Settings") {
                showingLocationSettings = true
            })
        }
        .sheet(isPresented: $showingLocationHistory) {
            LocationHistoryView()
                .environmentObject(locationService)
        }
        .sheet(isPresented: $showingSafetyZones) {
            SafetyZonesView()
                .environmentObject(mapKitService)
        }
        .sheet(isPresented: $showingEmergencyContacts) {
            EmergencyContactsView()
        }
        .sheet(isPresented: $showingLocationSettings) {
            LocationSettingsView()
                .environmentObject(locationService)
        }
        .onAppear {
            locationService.startLocationTracking()
        }
    }
}

// MARK: - Live Location Status Card
struct LiveLocationStatusCard: View {
    @EnvironmentObject var locationService: LocationService
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: locationService.isLocationEnabled ? "location.fill" : "location.slash")
                    .font(.title)
                    .foregroundColor(locationService.isLocationEnabled ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Tracking")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(locationService.isLocationEnabled ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundColor(locationService.isLocationEnabled ? .green : .red)
                }
                
                Spacer()
                
                // Pulse animation for active tracking
                if locationService.isLocationEnabled {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .scaleEffect(1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: locationService.isLocationEnabled
                        )
                }
            }
            
            if let location = locationService.currentLocation {
                VStack(spacing: 8) {
                    HStack {
                        Text("Last Updated:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(location.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Accuracy:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("±\(Int(location.horizontalAccuracy))m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Current Location Details Card
struct CurrentLocationDetailsCard: View {
    @EnvironmentObject var locationService: LocationService
    @State private var address: String = "Loading..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Current Location")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let location = locationService.currentLocation {
                VStack(spacing: 12) {
                    // Coordinates
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latitude")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.6f", location.coordinate.latitude))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Longitude")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.6f", location.coordinate.longitude))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Divider()
                    
                    // Address
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                    
                    // Speed and Heading
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(location.speed >= 0 ? String(format: "%.1f km/h", location.speed * 3.6) : "N/A")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Heading")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(location.course >= 0 ? String(format: "%.0f°", location.course) : "N/A")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                Text("Location not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadAddress()
        }
        .onChange(of: locationService.currentLocation) { _, _ in
            loadAddress()
        }
    }
    
    private func loadAddress() {
        guard locationService.currentLocation != nil else { return }
        
        locationService.getAddressFromLocation { address in
            if let address = address {
                self.address = address
            } else {
                self.address = "Address not available"
            }
        }
    }
}

// MARK: - Safety Information Card
struct SafetyInformationCard: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mapKitService: MapKitService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Safety Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Safety Score
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Safety Score")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(locationService.getSafetyScore())")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(safetyScoreColor)
                    }
                    
                    Spacer()
                    
                    // Safety Zone
                    if let currentZone = mapKitService.getCurrentSafetyZone() {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Current Zone")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(currentZone.title ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color(currentZone.color))
                        }
                    }
                }
                
                Divider()
                
                // Nearby Incidents
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nearby Incidents")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(mapKitService.nearbyIncidents.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last 24h")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Updated now")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var safetyScoreColor: Color {
        let score = locationService.getSafetyScore()
        switch score {
        case 80...100:
            return .green
        case 60...79:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Location Controls Card
struct LocationControlsCard: View {
    @EnvironmentObject var locationService: LocationService
    @State private var isSharingLocation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Location Controls")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Location Tracking Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Tracking")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Track your location for safety")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { locationService.isTrackingLocation },
                        set: { isOn in
                            if isOn {
                                locationService.startLocationTracking()
                            } else {
                                locationService.stopLocationTracking()
                            }
                        }
                    ))
                }
                
                Divider()
                
                // Location Sharing Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share Location")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Share with emergency contacts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isSharingLocation)
                }
                
                Divider()
                
                // Background Location Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Background Tracking")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Track location when app is closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { locationService.isLocationEnabled },
                        set: { _ in
                            locationService.requestLocationPermission()
                        }
                    ))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    @EnvironmentObject var locationService: LocationService
    @State private var showingLocationHistory = false
    @State private var showingSafetyZones = false
    @State private var showingEmergencyContacts = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                LiveLocationQuickActionButton(
                    icon: "clock.arrow.circlepath",
                    title: "Location History",
                    color: .blue
                ) {
                    showingLocationHistory = true
                }
                
                LiveLocationQuickActionButton(
                    icon: "shield.fill",
                    title: "Safety Zones",
                    color: .green
                ) {
                    showingSafetyZones = true
                }
                
                LiveLocationQuickActionButton(
                    icon: "person.2.fill",
                    title: "Emergency Contacts",
                    color: .red
                ) {
                    showingEmergencyContacts = true
                }
                
                LiveLocationQuickActionButton(
                    icon: "location.circle",
                    title: "Center on Me",
                    color: .purple
                ) {
                    // Center on user location
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Location History Preview Card
struct LocationHistoryPreviewCard: View {
    @EnvironmentObject var locationService: LocationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Recent Locations")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Show full history
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if locationService.locationHistory.isEmpty {
                Text("No location history available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(locationService.locationHistory.prefix(3).enumerated()), id: \.offset) { index, location in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Text(location.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.1f km/h", location.speed * 3.6))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}



// MARK: - Live Location Quick Action Button
struct LiveLocationQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Location History View
struct LocationHistoryView: View {
    @EnvironmentObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(locationService.locationHistory.enumerated()), id: \.offset) { index, location in
                    LocationHistoryRow(location: location, index: index)
                }
            }
            .navigationTitle("Location History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                },
                trailing: Button("Clear") {
                    locationService.clearLocationHistory()
                }
            )
        }
    }
}

// MARK: - Location History Row
struct LocationHistoryRow: View {
    let location: CLLocation
    let index: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Location \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(location.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f km/h", location.speed * 3.6))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("±\(Int(location.horizontalAccuracy))m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Safety Zones View
struct SafetyZonesView: View {
    @EnvironmentObject var mapKitService: MapKitService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(mapKitService.safetyZones.enumerated()), id: \.offset) { _, zone in
                    SafetyZoneRow(zone: zone)
                }
            }
            .navigationTitle("Safety Zones")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// MARK: - Safety Zone Row
struct SafetyZoneRow: View {
    let zone: SafetyZoneAnnotation
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(zone.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(zone.title ?? "Unknown Zone")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(zone.subtitle ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Risk \(zone.riskLevel)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(zone.color).opacity(0.2))
                .foregroundColor(Color(zone.color))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location Settings View
struct LocationSettingsView: View {
    @EnvironmentObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Location Services") {
                    HStack {
                        Text("Location Access")
                        Spacer()
                        Text(locationService.authorizationStatus.displayName)
                            .foregroundColor(locationService.isLocationEnabled ? .green : .red)
                    }
                    
                    Button("Request Permission") {
                        locationService.requestLocationPermission()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Tracking Settings") {
                    HStack {
                        Text("Background Updates")
                        Spacer()
                        Text(locationService.isLocationEnabled ? "Enabled" : "Disabled")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Accuracy")
                        Spacer()
                        Text("Best")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Privacy") {
                    Button("Clear Location History") {
                        locationService.clearLocationHistory()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Location Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// MARK: - Extensions
extension CLAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }
}

#Preview {
    LiveLocationView()
        .environmentObject(LocationService())
        .environmentObject(MapKitService())
}
