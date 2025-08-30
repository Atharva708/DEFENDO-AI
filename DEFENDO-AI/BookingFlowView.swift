//
//  BookingFlowView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI

struct BookingFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var selectedService: ServiceType = .securityGuard
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedDuration = 4
    @State private var location = ""
    @State private var specialInstructions = ""
    
    let steps = ["Select Service", "Date & Time", "Duration & Location", "Confirm & Pay"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressBarView(currentStep: currentStep, steps: steps)
                    .padding()
                
                // Content
                TabView(selection: $currentStep) {
                    ServiceSelectionView(selectedService: $selectedService)
                        .tag(0)
                    
                    DateTimeSelectionView(selectedDate: $selectedDate, selectedTime: $selectedTime)
                        .tag(1)
                    
                    DurationLocationView(selectedDuration: $selectedDuration, location: $location, specialInstructions: $specialInstructions)
                        .tag(2)
                    
                    ConfirmPaymentView(
                        selectedService: selectedService,
                        selectedDate: selectedDate,
                        selectedTime: selectedTime,
                        selectedDuration: selectedDuration,
                        location: location
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                HStack {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation {
                                currentStep -= 1
                            }
                        }) {
                            Text("Back")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentStep < 3 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
<<<<<<< HEAD
                            // Handle booking confirmation and payment
                            processBooking()
                        }
                    }) {
                        Text(currentStep == 3 ? "Confirm & Pay" : "Next")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canProceedToNextStep())
=======
                            // Handle booking confirmation
                            appState.currentScreen = .dashboard
                        }
                    }) {
                        Text(currentStep == 3 ? "Confirm" : "Next")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(currentStep == 0 && selectedService == nil)
>>>>>>> 08c75ea883b9f00010ae8a9cfcd01498718d487c
                }
                .padding()
            }
            .navigationTitle("Book Service")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                appState.currentScreen = .dashboard
            })
        }
    }
<<<<<<< HEAD
    
    private func canProceedToNextStep() -> Bool {
        switch currentStep {
        case 0:
            return selectedService != nil
        case 1:
            return selectedDate > Date() && selectedTime > Date()
        case 2:
            return selectedDuration > 0 && !location.isEmpty
        case 3:
            return true // Payment step - always allow proceeding
        default:
            return false
        }
    }
    
    private func processBooking() {
        // Create booking object
        let booking = Booking(
            id: UUID().uuidString,
            serviceType: selectedService,
            provider: selectedService == .securityGuard ? "Elite Security Services" : "SkyWatch Drones",
            date: selectedDate,
            duration: selectedDuration,
            location: location,
            status: .pending,
            price: calculateTotalPrice()
        )
        
        // Process payment (simulated)
        processPayment { success in
            if success {
                // Save booking to database/backend
                saveBooking(booking)
                
                // Navigate back to dashboard
                DispatchQueue.main.async {
                    self.appState.currentScreen = .dashboard
                }
            } else {
                // Handle payment failure
                print("Payment failed")
            }
        }
    }
    
    private func calculateTotalPrice() -> Double {
        let hourlyRate = selectedService == .securityGuard ? 25.0 : 35.0
        return hourlyRate * Double(selectedDuration)
    }
    
    private func processPayment(completion: @escaping (Bool) -> Void) {
        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Simulate successful payment
            completion(true)
        }
    }
    
    private func saveBooking(_ booking: Booking) {
        // Save booking to local storage or backend
        // This would typically involve an API call
        print("Booking saved: \(booking.id)")
    }
=======
>>>>>>> 08c75ea883b9f00010ae8a9cfcd01498718d487c
}

// MARK: - Progress Bar
struct ProgressBarView: View {
    let currentStep: Int
    let steps: [String]
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    HStack(spacing: 8) {
                        // Step Circle
                        ZStack {
                            Circle()
                                .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 30, height: 30)
                            
                            if index < currentStep {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            } else if index == currentStep {
                                Image(systemName: stepIcon(for: index))
                                    .foregroundColor(.white)
                                    .font(.caption)
                            } else {
                                Image(systemName: stepIcon(for: index))
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        
                        // Connector Line
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            // Step Labels
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    Text(steps[index])
                        .font(.caption)
                        .foregroundColor(index <= currentStep ? .blue : .gray)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func stepIcon(for index: Int) -> String {
        switch index {
        case 0: return "person.2.fill"
        case 1: return "calendar"
        case 2: return "location.fill"
        case 3: return "creditcard.fill"
        default: return "circle"
        }
    }
}

// MARK: - Service Selection
struct ServiceSelectionView: View {
    @Binding var selectedService: ServiceType
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Select Service Type")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Service Options
                VStack(spacing: 15) {
                    ServiceCard(
                        service: .securityGuard,
                        title: "Security Guard",
                        description: "Professional on-site security personnel",
                        price: "$25/hr",
                        features: ["Physical presence", "Patrol service", "Emergency response", "Incident reporting"],
                        isSelected: selectedService == .securityGuard
                    ) {
                        selectedService = .securityGuard
                    }
                    
                    ServiceCard(
                        service: .dronePatrol,
                        title: "Drone Patrol",
                        description: "Aerial surveillance and monitoring",
                        price: "$35/hr",
                        features: ["Live video feed", "Thermal imaging", "Wide area coverage", "Real-time alerts"],
                        isSelected: selectedService == .dronePatrol
                    ) {
                        selectedService = .dronePatrol
                    }
                }
                
                // Quick Rebook Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Quick Rebook")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        QuickRebookCard(
                            service: "Security Guard",
                            details: "Elite Security Services • Downtown Office • 4 hours"
                        )
                        
                        QuickRebookCard(
                            service: "Drone Patrol",
                            details: "SkyWatch Drones • Residential Area • 2 hours"
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct ServiceCard: View {
    let service: ServiceType
    let title: String
    let description: String
    let price: String
    let features: [String]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: service == .securityGuard ? "person.2.fill" : "eye.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(price)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Radio Button
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Features
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 5) {
                    ForEach(features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickRebookCard: View {
    let service: String
    let details: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(service)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(details)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Date & Time Selection
struct DateTimeSelectionView: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Date & Time")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.headline)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time")
                        .font(.headline)
                    
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Popular Times")
                        .font(.headline)
                    
                    HStack(spacing: 10) {
                        ForEach(["18:00", "20:00", "22:00"], id: \.self) { time in
                            Button(time) {
                                // Set time
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Duration & Location
struct DurationLocationView: View {
    @Binding var selectedDuration: Int
    @Binding var location: String
    @Binding var specialInstructions: String
    
    let durations = [1, 2, 4, 8, 12, 24]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Duration & Location")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Duration")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ForEach(durations, id: \.self) { duration in
                            Button("\(duration) hour\(duration == 1 ? "" : "s")") {
                                selectedDuration = duration
                            }
                            .padding()
                            .background(selectedDuration == duration ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedDuration == duration ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Location")
                        .font(.headline)
                    
                    TextField("Enter location", text: $location)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Special Instructions (Optional)")
                        .font(.headline)
                    
                    TextField("Any specific requirements or notes...", text: $specialInstructions, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

// MARK: - Confirm & Payment
struct ConfirmPaymentView: View {
    let selectedService: ServiceType
    let selectedDate: Date
    let selectedTime: Date
    let selectedDuration: Int
    let location: String
    
    @State private var selectedPaymentMethod = "Credit/Debit Card"
    
    var totalPrice: Double {
        let hourlyRate = selectedService == .securityGuard ? 25.0 : 35.0
        return hourlyRate * Double(selectedDuration)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Confirm & Pay")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Booking Summary
                VStack(alignment: .leading, spacing: 15) {
                    Text("Booking Summary")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        SummaryRow(title: "Service", value: selectedService == .securityGuard ? "Security Guard" : "Drone Patrol")
                        SummaryRow(title: "Date & Time", value: formatDateTime())
                        SummaryRow(title: "Duration", value: "\(selectedDuration) hours")
                        SummaryRow(title: "Location", value: location)
                        Divider()
                        SummaryRow(title: "Total", value: "$\(String(format: "%.0f", totalPrice))", isBold: true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Available Providers
                VStack(alignment: .leading, spacing: 15) {
                    Text("Available Providers")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        ProviderCard(
                            name: "Elite Security Services",
                            rating: 4.8,
                            reviews: 156,
                            distance: "0.3 miles",
                            price: "$25/hr",
                            eta: "15 mins"
                        )
                        
                        ProviderCard(
                            name: "SkyWatch Drones",
                            rating: 4.9,
                            reviews: 89,
                            distance: "0.8 miles",
                            price: "$35/hr",
                            eta: "10 mins"
                        )
                    }
                }
                
                // Payment Method
                VStack(alignment: .leading, spacing: 15) {
                    Text("Payment Method")
                        .font(.headline)
                    
                    VStack(spacing: 10) {
                        PaymentMethodCard(
                            title: "Credit/Debit Card",
                            isSelected: selectedPaymentMethod == "Credit/Debit Card"
                        ) {
                            selectedPaymentMethod = "Credit/Debit Card"
                        }
                        
                        PaymentMethodCard(
                            title: "SecureNow Wallet",
                            isSelected: selectedPaymentMethod == "SecureNow Wallet"
                        ) {
                            selectedPaymentMethod = "SecureNow Wallet"
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func formatDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: selectedDate)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(isBold ? .bold : .regular)
        }
    }
}

struct ProviderCard: View {
    let name: String
    let rating: Double
    let reviews: Int
    let distance: String
    let price: String
    let eta: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                        Text("(\(reviews) reviews)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("ETA: \(eta)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text(distance)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Verified")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PaymentMethodCard: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BookingFlowView()
        .environmentObject(AppState())
}
