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
    @State private var timeRemaining = 15 // 5 minutes in seconds
    @State private var safeWord = ""
    @State private var showingSafeWordInput = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var currentAlertId: String?
    @State private var showingLocationPermission = false
    @State private var showingEmergencyContacts = false
    @State private var emergencyLocationData: [String: Any] = [:]
    @State private var cancellables = Set<AnyCancellable>()
    
    @State private var escalationTimerCancellable: AnyCancellable?
    @State private var isEscalated = false
    
    @State private var pulse = false
    
    @State private var sosLogs: [SOSLogEntry] = []
    
    // Added states for showing message composer
    @State private var showingMessageComposer = false
    @State private var messageRecipients: [String] = []
    @State private var emergencyMessage: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let totalTime = 15
    
    var body: some View {
        ZStack {
            // Animated Red Gradient Background with blur overlay and vignette
            LinearGradient(
                gradient: Gradient(colors: [Color.red, Color.orange.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VisualEffectBlur(effect: UIBlurEffect(style: .systemThinMaterialDark))
                .ignoresSafeArea()
            
            // Subtle vignette overlay for depth
            Color.black.opacity(0.35)
                .blendMode(.multiply)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                header
                
                Spacer()
                
                // Main SOS Button & Status Area with glassy background card (VisualEffectBlur)
                VStack(spacing: 25) {
                    VisualEffectBlur(effect: UIBlurEffect(style: .systemMaterialDark))
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.red.opacity(0.8), radius: 20, x: 0, y: 10)
                        .overlay(
                            Group {
                                if isSOSActive {
                                    activeSOSContent
                                } else {
                                    inactiveSOSContent
                                }
                            }
                            .padding(40)
                        )
                        .padding(.horizontal, 30)
                    
                }
                
                Spacer()
                
                emergencyInfo
                slideToCancel
                recentActions
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
        .sheet(isPresented: $showingEmergencyContacts) {
            EmergencyContactsView()
                .environmentObject(emergencyContactService)
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
                .foregroundColor(.white)
        }
        .sheet(isPresented: $showingMessageComposer) {
            // Due to iOS privacy restrictions, user must manually send the SMS when presented
            MessageComposeView(recipients: messageRecipients, body: emergencyMessage)
        }
    }
    
    // MARK: - Extracted Views
    
    private var header: some View {
        HStack {
            Button(action: {
                appState.currentScreen = .dashboard
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        VisualEffectBlur(effect: UIBlurEffect(style: .systemThinMaterialDark))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.red.opacity(0.7), radius: 8, x: 0, y: 2)
            }
            .fixedSize()
            
            Spacer()
            
            VStack(spacing: 6) {
                Text("EMERGENCY SOS")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .shadow(color: Color.red.opacity(0.9), radius: 4, x: 0, y: 0)
                    .padding(.bottom, 4)
                
                if let user = authService.currentUser {
                    Text(user.name)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                        .shadow(color: Color.black.opacity(0.7), radius: 1, x: 0, y: 0)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingSafeWordInput = true
            }) {
                Text("Safe Word")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        VisualEffectBlur(effect: UIBlurEffect(style: .systemThinMaterialDark))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.red.opacity(0.7), radius: 8, x: 0, y: 2)
            }
            .fixedSize()
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var emergencyInfo: some View {
        if isSOSActive {
            VStack(spacing: 18) {
                if let location = locationService.currentLocation {
                    VStack(spacing: 8) {
                        Text("Your Location")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(locationService.lastKnownAddress ?? "Unknown location")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(12)
                    .shadow(color: Color.red.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                
                Button(action: {
                    showingEmergencyContacts = true
                }) {
                    Text("View Emergency Contacts")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 40)
                        .background(
                            VisualEffectBlur(effect: UIBlurEffect(style: .systemThinMaterialDark))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.8), radius: 12, x: 0, y: 5)
                }
            }
            .padding(.horizontal, 30)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var slideToCancel: some View {
        if isSOSActive {
            VStack(spacing: 18) {
                Text("Slide to cancel emergency")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.bottom, 6)
                
                ZStack {
                    VisualEffectBlur(effect: UIBlurEffect(style: .systemThinMaterialDark))
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .frame(width: 260, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.red.opacity(0.6), radius: 12, x: 0, y: 6)
                    
                    HStack {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.red.opacity(0.8), radius: 15, x: 0, y: 0)
                            .scaleEffect(isDragging ? 0.95 : 1.0)
                            .offset(x: dragOffset.width)
                            .overlay(
                                Image(systemName: "hand.point.right.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.red)
                            )
                            .opacity(pulse ? 0.85 : 1)
                            .animation(
                                Animation.easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true),
                                value: pulse
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                        isDragging = true
                                    }
                                    .onEnded { _ in
                                        if dragOffset.width > 130 {
                                            cancelSOS()
                                        }
                                        dragOffset = .zero
                                        isDragging = false
                                    }
                            )
                            .onAppear {
                                pulse = true
                            }
                        
                        Spacer()
                    }
                    .frame(width: 260, height: 60)
                    
                    Text("Cancel")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.white.opacity(0.85))
                        .offset(x: dragOffset.width / 2)
                        .shadow(color: Color.black.opacity(0.7), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.bottom, 30)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var recentActions: some View {
        if !sosLogs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Emergency Actions")
                    .font(.headline)
                    .foregroundColor(.white)
                ForEach(sosLogs.sorted(by: { $0.timestamp > $1.timestamp })) { log in
                    HStack(alignment: .top) {
                        Image(systemName: log.type == .call ? "phone.fill" : "message.fill")
                            .foregroundColor(log.type == .call ? .green : .blue)
                        VStack(alignment: .leading) {
                            Text("\(log.contactName) (\(log.contactPhone))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text(log.type == .call ? "Call successful" : "Text sent: \(log.message ?? "")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(log.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 30)
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Active SOS Content View
    
    @ViewBuilder
    private var activeSOSContent: some View {
        VStack(spacing: 25) {
            // Glowing animated icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 140, height: 140)
                    .blur(radius: 15)
                    .opacity(isSOSActive ? 1 : 0)
                    .animation(
                        Animation.easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: true),
                        value: isSOSActive
                    )
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.red)
                    .shadow(color: Color.red.opacity(0.9), radius: 20, x: 0, y: 0)
            }
            
            Text("SOS ACTIVATED")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(Color.red.opacity(0.95))
                .shadow(color: Color.red.opacity(0.8), radius: 6, x: 0, y: 0)
            
            Text("Emergency services notified")
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.85))
            
            // Circular Progress Indicator with numeric timer in center
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 14)
                    .frame(width: 130, height: 130)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(totalTime))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color.red, Color.orange]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                    .animation(.linear(duration: 1), value: timeRemaining)
                
                Text(timeString(from: timeRemaining))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.red)
                    .shadow(color: Color.red.opacity(0.9), radius: 4, x: 0, y: 0)
            }
            
            if isEscalated {
                Text("Escalation in progress")
                    .font(.subheadline)
                    .foregroundColor(Color.orange.opacity(0.85))
                    .fontWeight(.semibold)
                    .shadow(color: Color.orange.opacity(0.75), radius: 6, x: 0, y: 0)
            }
        }
    }
    
    // MARK: - Inactive SOS Content View
    
    @ViewBuilder
    private var inactiveSOSContent: some View {
        VStack(spacing: 30) {
            Text("EMERGENCY SOS")
                .font(.title)
                .fontWeight(.heavy)
                .foregroundColor(.white)
            
            Text("Tap to activate emergency response")
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // SOS Button with glowing ring and bigger icon
            Button(action: {
                activateSOS()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 170, height: 170)
                        .shadow(color: Color.red.opacity(0.7), radius: 30, x: 0, y: 10)
                    
                    Circle()
                        .stroke(Color.red.opacity(isDragging ? 0.9 : 0), lineWidth: 8)
                        .frame(width: 190, height: 190)
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isDragging)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(color: Color.white.opacity(0.9), radius: 10, x: 0, y: 0)
                }
            }
            .scaleEffect(isDragging ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isDragging)
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
        
        // Call all emergency contacts immediately
        for contact in emergencyContactService.emergencyContacts {
            emergencyContactService.callEmergencyContact(contact)
            sosLogs.append(SOSLogEntry(timestamp: Date(), type: .call, contactName: contact.name, contactPhone: contact.phone, message: nil))
        }
        // Note: iOS requires user confirmation for each call initiated; fully automatic calling without confirmation is not allowed by Apple.
        
        // Prepare emergency message (do not send)
        let emergencyMessage = """
        SOS Emergency Alert - Please check on me immediately
        
        Location: \(locationService.lastKnownAddress ?? "Unknown location")
        Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)
        Time: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
        
        // Notify all emergency contacts with message
        emergencyContactService.notifyAllEmergencyContacts(location: locationService.getLocationString(), message: emergencyMessage)
        
        // Schedule notification
        notificationService.scheduleSOSNotification(
            location: locationService.getLocationString(),
            timeRemaining: timeRemaining
        )
        
        // Start location tracking if not already active
        if !locationService.isTrackingLocation {
            locationService.startLocationTracking()
        }
        
        // Start escalation timer (10 seconds)
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
        \nLocation: \(currentAddress)
        Coordinates: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)
        Time: \(now.formatted(date: .abbreviated, time: .shortened))
        """
        // Call all emergency contacts
        for contact in emergencyContactService.emergencyContacts {
            emergencyContactService.callEmergencyContact(contact)
            sosLogs.append(SOSLogEntry(timestamp: Date(), type: .call, contactName: contact.name, contactPhone: contact.phone, message: nil))
        }
        // Note: iOS requires user confirmation for each call initiated; fully automatic calling without confirmation is not allowed by Apple.
        
        // Send message to all emergency contacts
        emergencyContactService.notifyAllEmergencyContacts(location: locationString, message: timerEndMessage)
        // Note: SMS send is triggered, but actual delivery can't be confirmed programmatically with URL scheme.
        for contact in emergencyContactService.emergencyContacts {
            sosLogs.append(SOSLogEntry(timestamp: Date(), type: .sms, contactName: contact.name, contactPhone: contact.phone, message: timerEndMessage))
        }
        
        // Prepare to present message composer for manual SMS sending
        messageRecipients = emergencyContactService.emergencyContacts.map { $0.phone }
        emergencyMessage = timerEndMessage
        showingMessageComposer = true
        
        isSOSActive = false
        isEscalated = true
    }
    
    private func escalateSOS() {
        guard isSOSActive && !isEscalated else { return }
        isEscalated = true
        
        // Obtain current location and address at escalation time
        guard let currentLocation = locationService.currentLocation else {
            print("Escalation failed: current location unavailable")
            return
        }
        
        let currentAddress = locationService.lastKnownAddress ?? "Unknown location"
        let locationString = locationService.getLocationString()
        
        // Call all emergency contacts
        for contact in emergencyContactService.emergencyContacts {
            emergencyContactService.callEmergencyContact(contact)
            sosLogs.append(SOSLogEntry(timestamp: Date(), type: .call, contactName: contact.name, contactPhone: contact.phone, message: nil))
        }
        // Note: iOS requires user confirmation for each call initiated; fully automatic calling without confirmation is not allowed by Apple.
        
        // Send SMS to all emergency contacts with current location and address
        let escalationMessage = """
        Escalation Alert - Immediate attention required!
        
        Location: \(currentAddress)
        Coordinates: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)
        Time: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
        
        emergencyContactService.notifyAllEmergencyContacts(
            location: locationString,
            message: escalationMessage
        )
        // Note: SMS send is triggered, but actual delivery can't be confirmed programmatically with URL scheme.
        for contact in emergencyContactService.emergencyContacts {
            sosLogs.append(SOSLogEntry(timestamp: Date(), type: .sms, contactName: contact.name, contactPhone: contact.phone, message: escalationMessage))
        }
        
        print("SOS escalation triggered: called all emergency contacts and sent SMS to all contacts.")
    }
    
    private func cancelSOS() {
        isSOSActive = false
        timeRemaining = totalTime
        isEscalated = false
        
        // Cancel escalation timer if active
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
}
