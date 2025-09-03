//
//  SOSView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI
import Combine
import CoreLocation
import UIKit
import MessageUI

struct SOSLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: LogType
    let contactName: String
    let contactPhone: String
    let message: String?
    enum LogType { case sms, call }
}

struct VisualEffectBlur: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

struct SOSView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var emergencyContactService: EmergencyContactService
    @EnvironmentObject var apiService: APIService
    
    @State private var isSOSActive = false
    @State private var timeRemaining = 10 // 15 seconds total
    @State private var safeWord = ""
    @State private var showingSafeWordInput = false
    @State private var currentAlertId: String?
    @State private var showingLocationPermission = false
    @State private var cancellables = Set<AnyCancellable>()
    
    @State private var escalationTimerCancellable: AnyCancellable?
    @State private var isEscalated = false
    
    // Message composer states
    @State private var showingMessageComposer = false
    @State private var messageRecipients: [String] = []
    @State private var emergencyMessage: String = ""
    
    // Slider drag state
    @State private var dragOffsetX: CGFloat = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let totalTime = 10
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Button(action: {
                    activateSOS()
                }) {
                    Text("SOS")
                        .bold()
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 200)
                        .background(Circle().fill(Color.red))
                        .shadow(color: Color.red.opacity(0.7), radius: 20, x: 0, y: 10)
                }
                .disabled(isSOSActive)
                
                if isSOSActive {
                    Text(timeString(from: timeRemaining))
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.top, 60)
                        .padding(.bottom, )
                }
                
                Spacer()
                
                if isSOSActive {
                    VStack(spacing: 12) {
                        Text("Slide to Cancel")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.headline)
                        
                        SliderCancelView(dragOffsetX: $dragOffsetX, onCancel: {
                            cancelSOS()
                            dragOffsetX = 0
                        })
                        .frame(height:70)
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onReceive(timer) { _ in
            if isSOSActive && timeRemaining > 0 {
                timeRemaining -= 1
            }
            if isSOSActive && timeRemaining == 0 {
                notifyAllContactsOnTimerEnd()
            }
        }
        .sheet(isPresented: $showingSafeWordInput) {
            SafeWordInputView(safeWord: $safeWord)
        }
        .alert("Location Permission Required", isPresented: $showingLocationPermission) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("DEFENDO needs location access to provide emergency services. Please enable location access in Settings.")
                .foregroundColor(.primary)
        }
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposeView(recipients: messageRecipients, body: emergencyMessage)
        }
    }
    
    // MARK: - Functions
    
    private func activateSOS() {
        guard let location = locationService.getCurrentLocation() else {
            showingLocationPermission = true
            return
        }
        
        isSOSActive = true
        timeRemaining = totalTime
        isEscalated = false
        currentAlertId = UUID().uuidString
        
        if !notificationService.isAuthorized {
            notificationService.requestPermission()
        }
        
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
        
        for contact in emergencyContactService.emergencyContacts {
            emergencyContactService.callEmergencyContact(contact)
            // Removed sosLogs.append call here as per instructions
        }
        
        let emergencyMessage = """
        SOS Emergency Alert - Please check on me immediately
        
        Location: \(locationService.lastKnownAddress ?? "Unknown location")
        Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Time: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
        
        emergencyContactService.notifyAllEmergencyContacts(location: locationService.getLocationString(), message: emergencyMessage)
        
        notificationService.scheduleSOSNotification(
            location: locationService.getLocationString(),
            timeRemaining: timeRemaining
        )
        
        if !locationService.isTrackingLocation {
            locationService.startLocationTracking()
        }
        
        escalationTimerCancellable = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                escalationTimerCancellable?.cancel()
                escalationTimerCancellable = nil
                escalateSOS()
            }
    }
    
    private func notifyAllContactsOnTimerEnd() {
        guard isSOSActive else { return }
        guard let currentLocation = locationService.currentLocation else {
            print("No location available at timer end")
            return
        }
        let currentAddress = locationService.lastKnownAddress ?? "Unknown location"
        let locationString = locationService.getLocationString()
        let now = Date()
        let timerEndMessage = """
        Final SOS Alert - No response detected. Immediate attention required!
        
        Location: \(currentAddress)
        Coordinates: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)
        Time: \(now.formatted(date: .abbreviated, time: .shortened))
        """
        for contact in emergencyContactService.emergencyContacts {
            emergencyContactService.callEmergencyContact(contact)
            // Removed sosLogs.append call here as per instructions
        }
        
        emergencyContactService.notifyAllEmergencyContacts(location: locationString, message: timerEndMessage)
        for contact in emergencyContactService.emergencyContacts {
            // Removed sosLogs.append call here as per instructions
        }
        
        messageRecipients = emergencyContactService.emergencyContacts.map { $0.phone }
        emergencyMessage = timerEndMessage
        showingMessageComposer = true
        
        isSOSActive = false
        isEscalated = true
    }
    
    private func escalateSOS() {
        guard isSOSActive && !isEscalated else { return }
        isEscalated = true
        
        guard let currentLocation = locationService.currentLocation else {
            print("Escalation failed: current location unavailable")
            return
        }
        
        let currentAddress = locationService.lastKnownAddress ?? "Unknown location"
        let locationString = locationService.getLocationString()
        
        for contact in emergencyContactService.emergencyContacts {
            emergencyContactService.callEmergencyContact(contact)
            // Removed sosLogs.append call here as per instructions
        }
        
        let escalationMessage = """
        Escalation Alert - Immediate attention required!
        
        Location: \(currentAddress)
        Coordinates: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)
        Time: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
        
        emergencyContactService.notifyAllEmergencyContacts(location: locationString, message: escalationMessage)
        for contact in emergencyContactService.emergencyContacts {
            // Removed sosLogs.append call here as per instructions
        }
        
        print("SOS escalation triggered: called all emergency contacts and sent SMS to all contacts.")
    }
    
    private func cancelSOS() {
        isSOSActive = false
        timeRemaining = totalTime
        isEscalated = false
        
        escalationTimerCancellable?.cancel()
        escalationTimerCancellable = nil
        
        if let alertId = currentAlertId {
            apiService.updateSOSStatus(alertId: alertId, status: .cancelled)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("SOS cancellation failed: \(error)")
                        }
                    },
                    receiveValue: { _ in
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

struct SliderCancelView: View {
    @Binding var dragOffsetX: CGFloat
    let onCancel: () -> Void
    
    @State private var sliderWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let maxOffset = geo.size.width - 70 // 70 is the diameter of the circle
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                
                Capsule()
                    .fill(Color.red)
                    .frame(width: dragOffsetX + 70 > 0 ? dragOffsetX + 70 : 0)
                    .animation(.linear(duration: 0.1), value: dragOffsetX)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .offset(x: max(0, min(dragOffsetX, maxOffset)))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newOffset = value.translation.width
                                dragOffsetX = max(0, min(newOffset, maxOffset))
                            }
                            .onEnded { _ in
                                if dragOffsetX >= maxOffset * 0.9 {
                                    onCancel()
                                } else {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        dragOffsetX = 0
                                    }
                                }
                            }
                    )
            }
            .cornerRadius(28)
        }
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposeView
        init(parent: MessageComposeView) { self.parent = parent }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.parent.dismiss() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}

// ---- END MessageComposeView ----

#Preview {
    SOSView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
        .environmentObject(NotificationService())
        .environmentObject(LocationService())
        .environmentObject(EmergencyContactService())
        .environmentObject(APIService())
}
