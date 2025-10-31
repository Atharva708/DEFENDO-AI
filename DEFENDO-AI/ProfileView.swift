//
//  ProfileView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import MapKit
import CoreLocation
import ContactsUI
import LocalAuthentication

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
    @State private var showingAuthFailedAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ProfileHeaderView()
                    // Removed QuickActionsSection()
                    SettingsSection(showingSettings: $showingSettings)
                    EmergencyContactsSection(authenticateAndShowEmergencyContacts: authenticateAndShowEmergencyContacts)
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
                    .environmentObject(appState)
                    .environmentObject(authService)
                    .environmentObject(locationService)
                   // .environmentObject(emergencyContactService)
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await authService.signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Authentication Failed", isPresented: $showingAuthFailedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Unable to verify your identity. Please try again.")
            }
        }
    }

    func authenticateAndShowEmergencyContacts() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to access Emergency Contacts."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        showingEmergencyContacts = true
                    } else {
                        showingAuthFailedAlert = true
                    }
                }
            }
        } else {
            // No biometric available, optionally just show EmergencyContacts
            // But instruction does not specify, so do nothing or show alert:
            DispatchQueue.main.async {
                showingAuthFailedAlert = true
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

// -- QuickActionsSection removed as per instructions --

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
    let authenticateAndShowEmergencyContacts: () -> Void
    var body: some View {
        Button(action: {
            authenticateAndShowEmergencyContacts()
        }) {
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
    @State private var receiveNotifications = true
    @State private var shareLocation = true
    @State private var hideProfileInfo = false
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    Toggle("Receive Push Notifications", isOn: $receiveNotifications)
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Share Location", isOn: $shareLocation)
                    Toggle("Hide Profile Information", isOn: $hideProfileInfo)
                }
                
                Section(header: Text("Account Management")) {
                    Button("Manage Account") {
                        // Implement account management action
                    }
                    .foregroundColor(.blue)
                    
                    Button("Delete Account") {
                        // Implement delete account action
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct EmergencyContactsView: View {
    @EnvironmentObject var emergencyContactService: EmergencyContactService
    @State private var showingContactPicker = false
    
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
                        
                        Button("Pick from Contacts") {
                            showingContactPicker = true
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
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Emergency Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    // Dismiss view - assume environment dismiss or delegate
                },
                trailing: Button("Add") {
                    showingContactPicker = true
                }
            )
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView { name, phone in
                    // Immediately add contact after picking
                    let newContact = EmergencyContact(
                        id: UUID().uuidString,
                        name: name,
                        phone: phone,
                        relationship: "Contact"
                    )
                    emergencyContactService.addEmergencyContact(newContact)
                    showingContactPicker = false
                }
            }
        }
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
    @Binding var relationship: String // Though relationship is fixed to "Contact" now, keep for binding compatibility
    let relationships: [String]
    let onPickContact: () -> Void
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button(action: { onPickContact() }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Pick from Contacts")
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
                .opacity((name.isEmpty || phone.isEmpty) ? 0 : 1)
            )
        }
    }
}

struct ContactPickerView: UIViewControllerRepresentable {
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        init(parent: ContactPickerView) { self.parent = parent }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let phone = contact.phoneNumbers.first?.value.stringValue else { return }
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            parent.onSelect(name, phone)
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {}
    }
    let onSelect: (String, String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}

// -- Preview --
#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(LocationService())
        .environmentObject(EmergencyContactService())
}
