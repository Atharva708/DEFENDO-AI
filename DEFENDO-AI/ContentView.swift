//
//  ContentView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import MapKit

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView()
            } else if authService.isAuthenticated {
                DashboardView()
            } else {
                AuthenticationContainerView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Loading SecureNow...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // App Logo and Title
                VStack(spacing: 20) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("SecureNow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI-powered security companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button("Sign Up") {
                        // Navigate to sign up
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Sign In") {
                        // Navigate to sign in
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Continue as Guest") {
                        appState.userRole = .guest
                        appState.currentScreen = .dashboard
                    }
                    .buttonStyle(TextButtonStyle())
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            ProfessionalMapView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
                .tag(1)
            
            MarketplaceView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Explore")
                }
                .tag(2)
            
            BookingsView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Bookings")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .overlay(
            // Floating SOS Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        appState.currentScreen = .sos
                    }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        )
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Safety Score Card
                    SafetyScoreCard()
                    
                    // Quick Actions
                    QuickActionsGrid()
                    
                    // Recent Bookings
                    RecentBookingsCard()
                    
                    // AI Tips
                    AITipsCard()
                    
                    // Mini Heatmap
                    MiniHeatmapCard()
                }
                .padding()
            }
            .navigationTitle("SecureNow")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Safety Score Card
struct SafetyScoreCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.blue)
                Text("Safety Score")
                    .font(.headline)
                Spacer()
                Text("85")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            ProgressView(value: 0.85)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
            
            Text("Your area is currently safe")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Grid
struct QuickActionsGrid: View {
    @EnvironmentObject var locationService: LocationService
    @State private var showingLocationView = false
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
            QuickActionCard(icon: "location.fill", title: "Track My Location", color: .blue) {
                showingLocationView = true
            }
            QuickActionCard(icon: "calendar", title: "My Bookings", color: .green) {
                // Handle bookings action
            }
            QuickActionCard(icon: "exclamationmark.triangle.fill", title: "My Alerts", color: .orange) {
                // Handle alerts action
            }
            QuickActionCard(icon: "person.2.fill", title: "Emergency Contacts", color: .red) {
                // Handle emergency contacts action
            }
        }
        .sheet(isPresented: $showingLocationView) {
            ProfessionalMapView()
                .environmentObject(locationService)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    init(icon: String, title: String, color: Color, action: @escaping () -> Void = {}) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Bookings Card
struct RecentBookingsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Bookings")
                .font(.headline)
            
            ForEach(0..<2) { _ in
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Security Guard")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Downtown Office • 4 hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Rebook") {
                        // Handle rebook
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - AI Tips Card
struct AITipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Safety Tip")
                    .font(.headline)
            }
            
            Text("Book a guard at 8 PM in your area for enhanced security during evening hours.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Mini Heatmap Card
struct MiniHeatmapCard: View {
    @EnvironmentObject var locationService: LocationService
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingFullMap = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Safety Map")
                    .font(.headline)
                Spacer()
                if locationService.isLocationEnabled {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Button("Enable Location") {
                        locationService.requestLocationPermission()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            
            // Live Map View
            MapView(region: $region, userLocation: locationService.currentLocation)
                .frame(height: 120)
                .cornerRadius(8)
                .onTapGesture {
                    showingFullMap = true
                }
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Tap to expand")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(8)
                        }
                    }
                )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingFullMap) {
            ProfessionalMapView()
                .environmentObject(locationService)
        }
        .onChange(of: locationService.currentLocation) { newLocation in
            if let location = newLocation {
                withAnimation(.easeInOut(duration: 1.0)) {
                    region.center = location.coordinate
                }
            }
        }
        .onAppear {
            if let location = locationService.currentLocation {
                region.center = location.coordinate
            } else if !locationService.isLocationEnabled {
                locationService.requestLocationPermission()
            }
        }
    }
}

// MARK: - Map View
struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let userLocation: CLLocation?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .standard
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        // Update user location if available
        if let location = userLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = "Your Location"
            
            // Remove existing annotations and add new one
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // Use default user location view
            }
            
            let identifier = "UserLocationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}

// MARK: - Full Map View
struct FullMapView: View {
    @EnvironmentObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationView {
            VStack {
                if locationService.isLocationEnabled {
                    MapView(region: $region, userLocation: locationService.currentLocation)
                        .ignoresSafeArea(.all, edges: .bottom)
                        .onChange(of: locationService.currentLocation) { newLocation in
                            if let location = newLocation {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    region.center = location.coordinate
                                }
                            }
                        }
                        .onAppear {
                            if let location = locationService.currentLocation {
                                region.center = location.coordinate
                            }
                        }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Location Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("To show your live location on the map, please enable location access in Settings.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Enable Location") {
                            locationService.requestLocationPermission()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Live Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.clear)
            .foregroundColor(.blue)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
