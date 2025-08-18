//
//  ProfileView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showingSettings = false
    @State private var showingEmergencyContacts = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    ProfileHeaderView()
                    
                    // Quick Actions
                    QuickActionsSection()
                    
                    // Settings Section
                    SettingsSection()
                    
                    // Emergency Contacts
                    EmergencyContactsSection()
                    
                    // Safety Settings
                    SafetySettingsSection()
                    
                    // Sign Out Section
                    SignOutSection()
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
                    Task {
                        await authService.signOut()
                    }
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
            
            // Safety Score
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

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                QuickActionButton(icon: "person.2.fill", title: "Emergency Contacts", color: .red)
                QuickActionButton(icon: "location.fill", title: "Track Location", color: .blue)
                QuickActionButton(icon: "bell.fill", title: "Notifications", color: .orange)
                QuickActionButton(icon: "shield.fill", title: "Safety Settings", color: .green)
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {
            // Handle action
        }) {
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

struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Settings")
                .font(.headline)
            
            VStack(spacing: 0) {
                SettingsRow(icon: "person.fill", title: "Edit Profile", subtitle: "Update your information")
                SettingsRow(icon: "bell.fill", title: "Notifications", subtitle: "Manage alerts and updates")
                SettingsRow(icon: "lock.fill", title: "Privacy & Security", subtitle: "Control your data")
                SettingsRow(icon: "creditcard.fill", title: "Payment Methods", subtitle: "Manage your cards")
                SettingsRow(icon: "globe", title: "Language", subtitle: "English")
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        Button(action: {
            // Handle action
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmergencyContactsSection: View {
    @State private var showingEmergencyContacts = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Emergency Contacts")
                    .font(.headline)
                
                Spacer()
                
                Button("Manage") {
                    showingEmergencyContacts = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 10) {
                EmergencyContactRow(name: "Sarah Johnson", phone: "+1 (555) 987-6543", relationship: "Spouse")
                EmergencyContactRow(name: "Mike Smith", phone: "+1 (555) 456-7890", relationship: "Friend")
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingEmergencyContacts) {
            EmergencyContactsView()
        }
    }
}

struct EmergencyContactRow: View {
    let name: String
    let phone: String
    let relationship: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(phone)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(relationship)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .padding()
    }
}

struct SafetySettingsSection: View {
    @State private var locationTracking = true
    @State private var sosEnabled = true
    @State private var autoAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Safety Settings")
                .font(.headline)
            
            VStack(spacing: 0) {
                Toggle("Location Tracking", isOn: $locationTracking)
                    .padding()
                
                Divider()
                
                Toggle("SOS Emergency", isOn: $sosEnabled)
                    .padding()
                
                Divider()
                
                Toggle("Auto Alert Nearby Guards", isOn: $autoAlert)
                    .padding()
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    SettingsRow(icon: "person.fill", title: "Edit Profile", subtitle: "Update your information")
                    SettingsRow(icon: "envelope.fill", title: "Email Settings", subtitle: "Manage email preferences")
                    SettingsRow(icon: "phone.fill", title: "Phone Settings", subtitle: "Update phone number")
                }
                
                Section("Notifications") {
                    SettingsRow(icon: "bell.fill", title: "Push Notifications", subtitle: "Manage app alerts")
                    SettingsRow(icon: "speaker.wave.2.fill", title: "Sound & Haptics", subtitle: "Customize alerts")
                }
                
                Section("Privacy & Security") {
                    SettingsRow(icon: "lock.fill", title: "Privacy Settings", subtitle: "Control your data")
                    SettingsRow(icon: "key.fill", title: "Change Password", subtitle: "Update your password")
                    SettingsRow(icon: "shield.fill", title: "Two-Factor Auth", subtitle: "Enhanced security")
                }
                
                Section("Payment") {
                    SettingsRow(icon: "creditcard.fill", title: "Payment Methods", subtitle: "Manage your cards")
                    SettingsRow(icon: "wallet.pass.fill", title: "SecureNow Wallet", subtitle: "Digital wallet settings")
                }
                
                Section("Support") {
                    SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", subtitle: "Get help")
                    SettingsRow(icon: "envelope.fill", title: "Contact Us", subtitle: "Send us a message")
                    SettingsRow(icon: "star.fill", title: "Rate App", subtitle: "Share your feedback")
                }
                
                Section("About") {
                    SettingsRow(icon: "info.circle.fill", title: "About SecureNow", subtitle: "Version 1.0.0")
                    SettingsRow(icon: "doc.text.fill", title: "Terms of Service", subtitle: "Legal information")
                    SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", subtitle: "Data protection")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct EmergencyContactsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var contacts: [EmergencyContact] = [
        EmergencyContact(id: "1", name: "Sarah Johnson", phone: "+1 (555) 987-6543", relationship: "Spouse"),
        EmergencyContact(id: "2", name: "Mike Smith", phone: "+1 (555) 456-7890", relationship: "Friend")
    ]
    @State private var showingAddContact = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(contacts, id: \.id) { contact in
                    EmergencyContactRow(name: contact.name, phone: contact.phone, relationship: contact.relationship)
                }
                .onDelete(perform: deleteContact)
            }
            .navigationTitle("Emergency Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    showingAddContact = true
                }
            )
            .sheet(isPresented: $showingAddContact) {
                AddContactView(contacts: $contacts)
            }
        }
    }
    
    private func deleteContact(offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
    }
}

struct AddContactView: View {
    @Binding var contacts: [EmergencyContact]
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var relationship = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phone)
                    TextField("Relationship", text: $relationship)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    let newContact = EmergencyContact(
                        id: UUID().uuidString,
                        name: name,
                        phone: phone,
                        relationship: relationship
                    )
                    contacts.append(newContact)
                    dismiss()
                }
                .disabled(name.isEmpty || phone.isEmpty)
            )
        }
    }
}

struct SignOutSection: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSignOutAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Account")
                .font(.headline)
            
            Button(action: {
                showingSignOutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Sign Out")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(LocationService())
}
