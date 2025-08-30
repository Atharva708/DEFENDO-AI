//
//  SOSView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import Combine
import CoreLocation

struct SOSView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var emergencyContactService: EmergencyContactService
    @EnvironmentObject var apiService: APIService
    
    @State private var isSOSActive = false
    @State private var timeRemaining = 300 // 5 minutes in seconds
    @State private var safeWord = ""
    @State private var showingSafeWordInput = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var currentAlertId: String?
    @State private var showingLocationPermission = false
    @State private var showingEmergencyContacts = false
    @State private var emergencyLocationData: [String: Any] = [:]
    @State private var cancellables = Set<AnyCancellable>()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Button("Cancel") {
                        appState.currentScreen = .dashboard
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("EMERGENCY SOS")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let user = authService.currentUser {
                            Text(user.name)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Safe Word") {
                        showingSafeWordInput = true
                    }
                    .foregroundColor(.white)
                }
                .padding()
                
                Spacer()
                
                // Main SOS Button
                VStack(spacing: 20) {
                    if isSOSActive {
                        // Active SOS State
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                                .scaleEffect(isSOSActive ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isSOSActive)
                            
                            Text("SOS ACTIVATED")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text("Emergency services notified")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            // Countdown Timer
                            Text(timeString(from: timeRemaining))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    } else {
                        // Inactive SOS State
                        VStack(spacing: 20) {
                            Text("EMERGENCY SOS")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Tap to activate emergency response")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            // SOS Button
                            Button(action: {
                                activateSOS()
                            }) {
                                VStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                    
                                    Text("SOS")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 150, height: 150)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: .red.opacity(0.5), radius: 20)
                                )
                            }
                            .scaleEffect(isDragging ? 0.9 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isDragging)
                        }
                    }
                }
                
                Spacer()
                
                // Emergency Information
                if isSOSActive {
                    VStack(spacing: 15) {
                        // Location Info
                        if let location = locationService.currentLocation {
                            VStack(spacing: 5) {
                                Text("Your Location")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(locationService.lastKnownAddress ?? "Unknown location")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(8)
                        }
                        
                        // Emergency Contacts
                        Button("View Emergency Contacts") {
                            showingEmergencyContacts = true
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                // Slide to Cancel
                if isSOSActive {
                    VStack(spacing: 15) {
                        Text("Slide to cancel emergency")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 200, height: 50)
                            
                            HStack {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.white)
                                    .frame(width: 50, height: 50)
                                    .offset(x: dragOffset.width)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                dragOffset = value.translation
                                                isDragging = true
                                            }
                                            .onEnded { value in
                                                if dragOffset.width > 100 {
                                                    cancelSOS()
                                                }
                                                dragOffset = .zero
                                                isDragging = false
                                            }
                                    )
                                
                                Spacer()
                            }
                            .frame(width: 200, height: 50)
                            
                            Text("Cancel")
                                .font(.caption)
                                .foregroundColor(.black)
                                .offset(x: dragOffset.width)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            if isSOSActive && timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
        .sheet(isPresented: $showingSafeWordInput) {
            SafeWordInputView(safeWord: $safeWord)
        }
        .sheet(isPresented: $showingEmergencyContacts) {
            EmergencyContactsView()
<<<<<<< HEAD
                .environmentObject(emergencyContactService)
=======
>>>>>>> 08c75ea883b9f00010ae8a9cfcd01498718d487c
        }
        .alert("Location Permission Required", isPresented: $showingLocationPermission) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("SecureNow needs location access to provide emergency services. Please enable location access in Settings.")
        }
    }
    
    private func activateSOS() {
        guard let location = locationService.getCurrentLocation() else {
            showingLocationPermission = true
            return
        }
        
        isSOSActive = true
        timeRemaining = 300
        currentAlertId = UUID().uuidString
        
        // Get emergency location data
        emergencyLocationData = locationService.getEmergencyLocationData()
        
        // Request notification permission if not granted
        if !notificationService.isAuthorized {
            notificationService.requestPermission()
        }
        
        // Send SOS alert to backend
        let sosAlert = SOSAlertRequest(
            userId: authService.currentUser?.id ?? "guest",
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            description: "SOS Emergency Activated",
            timestamp: Date(),
            deviceInfo: DeviceInfo(
                platform: "iOS",
                version: UIDevice.current.systemVersion,
                model: UIDevice.current.model,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
        )
        
        apiService.sendSOSAlert(userId: sosAlert.userId, location: location, description: sosAlert.description)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("SOS Alert failed: \(error)")
                    }
                },
                receiveValue: { response in
                    print("SOS Alert sent successfully: \(response.alertId)")
                    self.currentAlertId = response.alertId
                }
            )
            .store(in: &cancellables)
        
        // Notify police department
        apiService.notifyPoliceDepartment(
            location: location,
            incidentType: "emergency_sos",
            description: "SOS Emergency Alert from SecureNow user"
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Police notification failed: \(error)")
                }
            },
            receiveValue: { response in
                print("Police notified: \(response.incidentId)")
            }
        )
        .store(in: &cancellables)
        
        // Notify emergency contacts with enhanced location data
        let emergencyMessage = """
        SOS Emergency Alert - Please check on me immediately
        
        Location: \(locationService.lastKnownAddress ?? "Unknown location")
        Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Time: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
        
        emergencyContactService.notifyAllEmergencyContacts(
            location: locationService.getLocationString(),
            message: emergencyMessage
        )
        
        // Schedule notification
        notificationService.scheduleSOSNotification(
            location: locationService.getLocationString(),
            timeRemaining: timeRemaining
        )
        
        // Start location tracking if not already active
        if !locationService.isTrackingLocation {
            locationService.startLocationTracking()
        }
    }
    
    private func cancelSOS() {
        isSOSActive = false
        timeRemaining = 300
        
        if let alertId = currentAlertId {
            apiService.updateSOSStatus(alertId: alertId, status: .cancelled)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("SOS cancellation failed: \(error)")
                        }
                    },
                    receiveValue: { response in
                        print("SOS cancelled successfully")
                    }
                )
                .store(in: &cancellables)
        }
        
        notificationService.cancelNotification(withIdentifier: "sos_emergency")
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct SafeWordInputView: View {
    @Binding var safeWord: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter Safe Word")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Enter your safe word to cancel SOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextField("Safe word", text: $safeWord)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Confirm") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(safeWord.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Safe Word")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

#Preview {
    SOSView()
        .environmentObject(AppState())
}
