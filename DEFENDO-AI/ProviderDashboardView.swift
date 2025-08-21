//
//  ProviderDashboardView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import MapKit

struct ProviderDashboardView: View {
    @EnvironmentObject var mapKitService: MapKitService
    @State private var selectedAnnotation: MKAnnotation?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map showing current location and provider-relevant overlays
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
                
                // Floating button to center map on user location
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            mapKitService.centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
                
                // Optionally, you can add your dashboard overlays/panels here
            }
            .onAppear {
                mapKitService.startLocationTracking()
                mapKitService.loadEmergencyContacts()
            }
            .navigationTitle("Provider Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// ---- The settings row remains at the end of your file ----

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.footnote)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// Preview with a MapKitService injected
#Preview {
    ProviderDashboardView()
        .environmentObject(MapKitService())
}
