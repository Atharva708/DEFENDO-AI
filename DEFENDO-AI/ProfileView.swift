//
//  ProfileView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - CLLocation Wrapper for Identifiable

struct IdentifiableLocation: Identifiable {
    let id = UUID()
    let location: CLLocation
}

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @State private var showingSettings = false
    @State private var showingEmergencyContacts = false
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ProfileHeaderView()
                    QuickActionsSection()
                    SettingsSection(showingSettings: $showingSettings)
                    EmergencyContactsSection(showingEmergencyContacts: $showingEmergencyContacts)
                    SafetySettingsSection()
                    SignOutSection(showingSignOutAlert: $showingSignOutAlert)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Settings") {
                showingSettings = true
            })
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingEmergencyContacts) {
                EmergencyContactsView()
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await authService.signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct ProfileHeaderView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @State private var showingMap = false
    @State private var region: MKCoordinateRegion = .init(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    var body: some View {
        VStack(spacing: 15) {
            // Profile Image
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // User Info
            VStack(spacing: 5) {
                Text(authService.currentUser?.name ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(authService.currentUser?.email ?? "user@email.com")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(authService.currentUser?.phone ?? "+1 (555) 123-4567")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Safety Score and Location Status
            HStack {
                VStack(alignment: .leading) {
                    Text("Safety Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(locationService.getSafetyScore())")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(safetyScoreColor)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Location Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(locationService.isLocationEnabled ? "Active" : "Inactive")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(locationService.isLocationEnabled ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Live Location Info (Address and Coordinates)
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    if let addr = locationService.lastKnownAddress {
                        Text(addr)
                            .font(.subheadline)
                    } else {
                        Text("Locating...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    // Show on map button if location available
                    if let loc = locationService.currentLocation {
                        Button(action: { showingMap = true }) {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                        }
                    }
                }
                if let current = locationService.currentLocation {
                    Text(String(format: "Lat: %.5f, Lon: %.5f", current.coordinate.latitude, current.coordinate.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 6)
            .padding(.horizontal)
            .padding(.bottom, 8)

            .sheet(isPresented: $showingMap) {
                if let userLocation = locationService.currentLocation {
                    let identifiable = IdentifiableLocation(location: userLocation)
                    Map(coordinateRegion: .constant(
                        MKCoordinateRegion(
                            center: userLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    ), annotationItems: [identifiable]) { location in
                        MapMarker(coordinate: location.location.coordinate, tint: .blue)
                    }
                    .ignoresSafeArea()
                } else {
                    Text("Location unavailable.")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            if let current = locationService.currentLocation {
                region.center = current.coordinate
            }
        }
    }

    private var safetyScoreColor: Color {
        let score = locationService.getSafetyScore()
        switch score {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .red
        }
    }
}

// -- Quick Actions Section, with dynamic location action --
struct QuickActionsSection: View {
    @EnvironmentObject var locationService: LocationService
    @State private var showingLocationMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                QuickActionButton(icon: "person.2.fill", title: "Emergency Contacts", color: .red) {
                    // Action for emergency contacts, e.g. open EmergencyContactsView
                }
                QuickActionButton(icon: "location.fill", title: "Track Location", color: .blue) {
                    showingLocationMap = true
                }
                QuickActionButton(icon: "bell.fill", title: "Notifications", color: .orange)
                QuickActionButton(icon: "shield.fill", title: "Safety Settings", color: .green)
            }
        }
        .sheet(isPresented: $showingLocationMap) {
            if let userLocation = locationService.currentLocation {
                let identifiable = IdentifiableLocation(location: userLocation)
                Map(coordinateRegion: .constant(
                    MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                ), annotationItems: [identifiable]) { location in
                    MapMarker(coordinate: location.location.coordinate, tint: .blue)
                }
                .ignoresSafeArea()
            } else {
                Text("Location unavailable.")
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
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

// MARK: - Placeholder/Minimal Implementations

struct SettingsSection: View {
    @Binding var showingSettings: Bool
    var body: some View {
        Button(action: { showingSettings = true }) {
            HStack {
                Image(systemName: "gear")
                Text("Settings")
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct EmergencyContactsSection: View {
    @Binding var showingEmergencyContacts: Bool
    var body: some View {
        Button(action: { showingEmergencyContacts = true }) {
            HStack {
                Image(systemName: "person.2.fill")
                Text("Emergency Contacts")
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct SafetySettingsSection: View {
    var body: some View {
        HStack {
            Image(systemName: "shield.fill")
            Text("Safety Settings")
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SignOutSection: View {
    @Binding var showingSignOutAlert: Bool
    var body: some View {
        Button(action: { showingSignOutAlert = true }) {
            HStack {
                Image(systemName: "arrow.backward.square")
                    .foregroundColor(.red)
                Text("Sign Out")
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Text("Settings go here")
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EmergencyContactsView: View {
    @EnvironmentObject var emergencyContactService: EmergencyContactService
    @State private var showingAddContact = false
    @State private var newContactName = ""
    @State private var newContactPhone = ""
    @State private var newContactRelationship = "Contact"
    
    let relationships = ["Contact", "Mother", "Father", "Spouse", "Sibling", "Friend", "Other"]
    
    var body: some View {
        NavigationView {
            VStack {
                if emergencyContactService.emergencyContacts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Emergency Contacts")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Add emergency contacts to receive SOS alerts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Contact") {
                            showingAddContact = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                } else {
                    List {
                        ForEach(emergencyContactService.emergencyContacts) { contact in
                            EmergencyContactRow(contact: contact)
                        }
                        .onDelete(perform: deleteContact)
                    }
                }
            }
            .navigationTitle("Emergency Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    // Dismiss view
                },
                trailing: Button("Add") {
                    showingAddContact = true
                }
            )
            .sheet(isPresented: $showingAddContact) {
                AddEmergencyContactView(
                    name: $newContactName,
                    phone: $newContactPhone,
                    relationship: $newContactRelationship,
                    relationships: relationships
                ) {
                    addNewContact()
                }
            }
        }
    }
    
    private func addNewContact() {
        let newContact = EmergencyContact(
            id: UUID().uuidString,
            name: newContactName,
            phone: newContactPhone,
            relationship: newContactRelationship
        )
        
        emergencyContactService.addEmergencyContact(newContact)
        
        // Reset form
        newContactName = ""
        newContactPhone = ""
        newContactRelationship = "Contact"
    }
    
    private func deleteContact(offsets: IndexSet) {
        for index in offsets {
            let contact = emergencyContactService.emergencyContacts[index]
            emergencyContactService.removeEmergencyContact(withId: contact.id)
        }
    }
}

struct EmergencyContactRow: View {
    let contact: EmergencyContact
    @EnvironmentObject var emergencyContactService: EmergencyContactService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                
                Text(contact.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(contact.relationship)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    emergencyContactService.callEmergencyContact(contact)
                }) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                Button(action: {
                    let message = "Emergency: Please check on me immediately. Location: \(emergencyContactService.getCurrentLocation() ?? "Unknown")"
                    emergencyContactService.sendSMSToEmergencyContact(contact, message: message)
                }) {
                    Image(systemName: "message.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddEmergencyContactView: View {
    @Binding var name: String
    @Binding var phone: String
    @Binding var relationship: String
    let relationships: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information")) {
                    TextField("Full Name", text: $name)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { rel in
                            Text(rel).tag(rel)
                        }
                    }
                }
            }
            .navigationTitle("Add Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                    dismiss()
                }
                .disabled(name.isEmpty || phone.isEmpty)
            )
        }
    }
}

// -- Preview --
#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(LocationService())
}
