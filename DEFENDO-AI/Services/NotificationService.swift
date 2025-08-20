//
//  NotificationService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import Foundation
import UserNotifications
import Combine

class NotificationService: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                self.checkAuthorizationStatus()
            }
            
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleSOSNotification(location: String, timeRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "SOS Emergency Activated"
        content.body = "Emergency services notified. Location: \(location). Time remaining: \(timeRemaining)s"
        content.sound = .defaultCritical
        content.categoryIdentifier = "SOS_EMERGENCY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "sos_emergency", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleBookingReminder(booking: Booking) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Security Service"
        content.body = "Your \(booking.serviceType == ServiceType.securityGuard ? "Security Guard" : "Drone Patrol") service starts in 30 minutes"
        content.sound = .default
        content.categoryIdentifier = "BOOKING_REMINDER"
        
        // Schedule 30 minutes before booking
        let bookingTime = booking.date
        let reminderTime = bookingTime.addingTimeInterval(-1800) // 30 minutes before
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime), repeats: false)
        let request = UNNotificationRequest(identifier: "booking_reminder_\(booking.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleProviderNotification(providerName: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Message from \(providerName)"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "PROVIDER_MESSAGE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "provider_message_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
