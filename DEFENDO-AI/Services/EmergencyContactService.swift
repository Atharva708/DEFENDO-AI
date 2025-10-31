//
//  EmergencyContactService.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import Foundation
import Contacts
import Combine
import UIKit
import LocalAuthentication

class EmergencyContactService: ObservableObject {
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var isAuthorized = false
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    
    private let contactStore = CNContactStore()
    
    private func authenticateWithBiometrics(reason: String = "Authenticate to manage emergency contacts", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        } else {
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    init() {
        checkAuthorizationStatus()
        loadSavedEmergencyContacts()
    }
    
    func requestContactPermission() {
        contactStore.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                self.checkAuthorizationStatus()
                
                if granted {
                    self.loadEmergencyContacts()
                }
            }
            
            if let error = error {
                print("Contact permission error: \(error)")
            }
        }
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        isAuthorized = authorizationStatus == .authorized
    }
    
    func loadEmergencyContacts() {
        guard isAuthorized else { return }
        
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
        
        do {
            var contacts: [EmergencyContact] = []
            
            try contactStore.enumerateContacts(with: request) { contact, stop in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                
                for phoneNumber in contact.phoneNumbers {
                    let phone = phoneNumber.value.stringValue
                    let relationship = self.determineRelationship(name: name, phone: phone)
                    
                    let emergencyContact = EmergencyContact(
                        id: UUID().uuidString,
                        name: name,
                        phone: phone,
                        relationship: relationship
                    )
                    contacts.append(emergencyContact)
                }
            }
            
            DispatchQueue.main.async {
                self.emergencyContacts = contacts
            }
        } catch {
            print("Error loading contacts: \(error)")
        }
    }
    
    private func determineRelationship(name: String, phone: String) -> String {
        // Simple logic to determine relationship based on name patterns
        let lowercasedName = name.lowercased()
        
        if lowercasedName.contains("mom") || lowercasedName.contains("mother") {
            return "Mother"
        } else if lowercasedName.contains("dad") || lowercasedName.contains("father") {
            return "Father"
        } else if lowercasedName.contains("spouse") || lowercasedName.contains("wife") || lowercasedName.contains("husband") {
            return "Spouse"
        } else if lowercasedName.contains("sister") || lowercasedName.contains("brother") {
            return "Sibling"
        } else {
            return "Contact"
        }
    }
    
    func addEmergencyContact(_ contact: EmergencyContact) {
        self.emergencyContacts.append(contact)
        self.saveEmergencyContacts()
    }
    
    func removeEmergencyContact(withId id: String) {
        self.emergencyContacts.removeAll { $0.id == id }
        self.saveEmergencyContacts()
    }
    
    func updateEmergencyContact(_ contact: EmergencyContact) {
        authenticateWithBiometrics(reason: "Authenticate to update emergency contact") { success in
            if success {
                if let index = self.emergencyContacts.firstIndex(where: { $0.id == contact.id }) {
                    self.emergencyContacts[index] = contact
                    self.saveEmergencyContacts()
                }
            } else {
                print("Biometric authentication failed")
            }
        }
    }
    
    private func saveEmergencyContacts() {
        // Save to UserDefaults for now, in production this would go to a database
        if let encoded = try? JSONEncoder().encode(emergencyContacts) {
            UserDefaults.standard.set(encoded, forKey: "emergency_contacts")
        }
    }
    
    private func loadSavedEmergencyContacts() {
        if let data = UserDefaults.standard.data(forKey: "emergency_contacts"),
           let contacts = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            emergencyContacts = contacts
        }
    }
    
    func callEmergencyContact(_ contact: EmergencyContact) {
        let phoneNumber = contact.phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    func sendSMSToEmergencyContact(_ contact: EmergencyContact, message: String) {
        let phoneNumber = contact.phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms://\(phoneNumber)&body=\(encodedMessage)") {
            UIApplication.shared.open(url)
        }
    }
    
    func notifyAllEmergencyContacts(location: String, message: String) {
        for contact in emergencyContacts {
            sendSMSToEmergencyContact(contact, message: "SOS Alert: \(message). Location: \(location)")
        }
    }
    
    func getEmergencyContactsForSOS() -> [EmergencyContact] {
        // Return contacts marked as emergency contacts or all contacts if none marked
        return emergencyContacts
    }
    
    func getCurrentLocation() -> String? {
        // This would typically get location from LocationService
        // For now, return a placeholder
        return "Current Location"
    }
    
    func getLocationString() -> String {
        // This would get the actual location string from LocationService
        return "Current Location"
    }
}
