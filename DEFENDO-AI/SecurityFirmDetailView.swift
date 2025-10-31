//
//  SecurityFirmDetailView.swift
//  DEFENDO-AI
//
//  Security firm detail view showing guards like dishes in Swiggy
//

import SwiftUI

// MARK: - Security Firm Detail View
struct SecurityFirmDetailView: View {
    let firm: SecurityFirm
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aggregatorService = SecurityAggregatorService.shared
    @StateObject private var cartService = SecurityCartService.shared
    @State private var searchQuery = ""
    @State private var selectedDate = Date()
    @State private var selectedTimeSlot = TimeSlot(startTime: "09:00", endTime: "17:00")
    @State private var showingDatePicker = false
    @State private var showingTimeSlotPicker = false
    
    // Search debouncing
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Firm Header
                    firmHeader
                    
                    // Date & Time Selection
                    dateTimeSelection
                    
                    // Guards Section
                    guardsSection
                }
                .padding()
            }
            .navigationTitle(firm.companyName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    cartButton
                }
            }
        }
        .onAppear {
            loadGuards()
        }
    }
    
    // MARK: - Firm Header
    private var firmHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Company Logo
                AsyncImage(url: URL(string: firm.logoUrl ?? "")) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Company Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(firm.companyName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if firm.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    
                    if let rating = firm.rating {
                        HStack(spacing: 4) {
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { index in
                                    Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                            }
                            Text(firm.ratingDisplay)
                                .fontWeight(.semibold)
                            
                            if let reviews = firm.totalReviews {
                                Text("(\(reviews) reviews)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let location = firm.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(firm.isCurrentlyOpen ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(firm.availabilityStatus)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(firm.isCurrentlyOpen ? .green : .red)
                    }
                }
                
                Spacer()
            }
            
            // Services offered
            if !firm.servicesOffered.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Services Offered")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(firm.servicesOffered, id: \.self) { service in
                            Text(service.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            
            // Contact Info
            if (firm.phone != nil) || (firm.email != nil) {
                HStack(spacing: 16) {
                    if let phone = firm.phone {
                        Button(action: {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                Text("Call")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(20)
                        }
                    }
                    
                    if let email = firm.email {
                        Button(action: {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                Text("Email")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Date & Time Selection
    private var dateTimeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Date & Time")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                // Date Selection
                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text(formatDate(selectedDate))
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Time Slot Selection
                Button(action: {
                    showingTimeSlotPicker = true
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text("\(selectedTimeSlot.startTime) - \(selectedTimeSlot.endTime)")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .sheet(isPresented: $showingTimeSlotPicker) {
            TimeSlotPickerSheet(selectedTimeSlot: $selectedTimeSlot)
        }
    }
    
    // MARK: - Guards Section
    private var guardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Guards")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !aggregatorService.securityGuards.isEmpty {
                    Text("\(aggregatorService.securityGuards.count) guards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Search Bar for Guards
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search guards...", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchQuery) { newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if !Task.isCancelled {
                                await aggregatorService.searchSecurityGuards(query: newValue, firmId: firm.id)
                            }
                        }
                    }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if aggregatorService.isLoading {
                ProgressView("Loading guards...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if aggregatorService.securityGuards.isEmpty {
                Text("No guards available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(aggregatorService.securityGuards) { securityGuard in
                        SecurityGuardCardView(securityGuard: securityGuard, selectedDate: selectedDate, selectedTimeSlot: selectedTimeSlot)
                    }
                }
            }
        }
    }
    
    // MARK: - Cart Button
    private var cartButton: some View {
        Button(action: {
            // Handle cart view
        }) {
            ZStack {
                Image(systemName: "cart.fill")
                    .font(.title2)
                
                if cartService.totalItems > 0 {
                    Text("\(cartService.totalItems)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .foregroundColor(.accentColor)
    }
    
    // MARK: - Helper Methods
    private func loadGuards() {
        Task {
            await aggregatorService.loadSecurityGuardsForFirm(firmId: firm.id)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Security Guard Card View
struct SecurityGuardCardView: View {
    let securityGuard: SecurityGuard
    let selectedDate: Date
    let selectedTimeSlot: TimeSlot
    @StateObject private var cartService = SecurityCartService.shared
    @State private var quantity = 1
    
    var body: some View {
        HStack(spacing: 12) {
            // Guard Profile Image
            AsyncImage(url: URL(string: securityGuard.profileImageUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Guard Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(securityGuard.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if securityGuard.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    // Availability indicator
                    Circle()
                        .fill(securityGuard.availabilityColor)
                        .frame(width: 8, height: 8)
                }
                
                if let rating = securityGuard.rating {
                    HStack(spacing: 4) {
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption2)
                            }
                        }
                        Text(securityGuard.ratingDisplay)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if let bookings = securityGuard.totalBookings {
                            Text("(\(bookings) bookings)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Specializations
                if !securityGuard.specializations.isEmpty {
                    Text(securityGuard.specializations.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
                
                // Experience and response time
                HStack(spacing: 12) {
                    if let experience = securityGuard.experience {
                        Text("\(experience) years exp")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let responseTime = securityGuard.responseTime {
                        Text("\(responseTime) min response")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Price and Add to Cart
            VStack(alignment: .trailing, spacing: 8) {
                Text(securityGuard.hourlyRateDisplay)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                
                if securityGuard.isAvailableForBooking {
                    HStack(spacing: 8) {
                        // Quantity selector
                        HStack(spacing: 4) {
                            Button(action: {
                                if quantity > 1 {
                                    quantity -= 1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.caption)
                            }
                            .disabled(quantity <= 1)
                            
                            Text("\(quantity)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(minWidth: 20)
                            
                            Button(action: {
                                quantity += 1
                            }) {
                                Image(systemName: "plus")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                        
                        // Add to cart button
                        Button(action: {
                            cartService.addGuardToCart(
                                guard: securityGuard,
                                quantity: quantity,
                                selectedDate: selectedDate,
                                selectedTimeSlot: selectedTimeSlot
                            )
                        }) {
                            Text("Add")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .cornerRadius(6)
                        }
                    }
                } else {
                    Text(securityGuard.availabilityStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Time Slot Picker Sheet
struct TimeSlotPickerSheet: View {
    @Binding var selectedTimeSlot: TimeSlot
    @Environment(\.dismiss) private var dismiss
    
    private let timeSlots = [
        TimeSlot(startTime: "09:00", endTime: "17:00"),
        TimeSlot(startTime: "17:00", endTime: "01:00"),
        TimeSlot(startTime: "01:00", endTime: "09:00")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Select Time Slot")
                    .font(.headline)
                    .padding()
                
                LazyVStack(spacing: 8) {
                    ForEach(timeSlots, id: \.startTime) { timeSlot in
                        Button(action: {
                            selectedTimeSlot = timeSlot
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(timeSlot.startTime) - \(timeSlot.endTime)")
                                        .font(.headline)
                                    Text(getTimeSlotDescription(timeSlot))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedTimeSlot.startTime == timeSlot.startTime {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTimeSlot.startTime == timeSlot.startTime ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                            )
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Time Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getTimeSlotDescription(_ timeSlot: TimeSlot) -> String {
        switch timeSlot.startTime {
        case "09:00":
            return "Day Shift"
        case "17:00":
            return "Evening Shift"
        case "01:00":
            return "Night Shift"
        default:
            return "Custom Time"
        }
    }
}

#Preview {
    SecurityFirmDetailView(firm: SecurityFirm(
        id: "1",
        companyName: "SecureGuard Solutions",
        logoUrl: nil,
        rating: 4.5,
        totalReviews: 128,
        location: "New York, NY",
        address: "123 Security St, New York, NY 10001",
        phone: "+1 (555) 123-4567",
        email: "contact@secureguard.com",
        website: "https://secureguard.com",
        description: "Professional security services",
        servicesOffered: ["Personal Security", "Event Security", "Corporate Security"],
        isVerified: true,
        isActive: true,
        deliveryTime: 15,
        minimumOrder: 100.0,
        deliveryFee: 5.0,
        currency: "USD",
        operatingHours: nil,
        coverageArea: ["Manhattan", "Brooklyn"],
        certifications: ["Licensed", "Insured"],
        insuranceInfo: "Fully insured",
        licenseNumber: "SEC123456",
        totalGuards: 25,
        availableGuards: 15,
        createdAt: "2023-01-15T10:30:00.000Z",
        updatedAt: "2024-01-15T10:30:00.000Z"
    ))
}

