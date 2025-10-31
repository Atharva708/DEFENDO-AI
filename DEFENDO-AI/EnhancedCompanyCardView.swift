import SwiftUI

// MARK: - Enhanced Company Card View
struct EnhancedCompanyCardView: View {
    let company: CompanyCard
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Section
            headerSection
            
            // Company Info Section
            companyInfoSection
            
            // Services Section
            if let serviceTypes = company.serviceTypes, !serviceTypes.isEmpty {
                servicesSection(serviceTypes)
            }
            
            // Contact & Verification Section
            contactSection
            
            // Expandable Details
            if isExpanded {
                expandedDetailsSection
            }
            
            // Action Buttons
            actionButtonsSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Company Logo
            AsyncImage(url: URL(string: company.logoUrl ?? "")) { phase in
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Company Name & Rating
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(company.companyName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    if company.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
                
                if let rating = company.rating {
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if let reviews = company.reviews {
                            Text("(\(reviews) reviews)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let city = company.city {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Expand/Collapse Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    // MARK: - Company Info Section
    private var companyInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = company.email {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let phone = company.phone {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Services Section
    private func servicesSection(_ serviceTypes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Services Offered")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(serviceTypes.prefix(4), id: \.self) { service in
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
            
            if serviceTypes.count > 4 {
                Text("+ \(serviceTypes.count - 4) more services")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Contact Section
    private var contactSection: some View {
        HStack(spacing: 16) {
            if let phone = company.phone {
                Button(action: {
                    // Handle phone call
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
            
            if let email = company.email {
                Button(action: {
                    // Handle email
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
            
            Spacer()
        }
    }
    
    // MARK: - Expanded Details Section
    private var expandedDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // Company Details
            VStack(alignment: .leading, spacing: 8) {
                Text("Company Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let createdAt = company.createdAt {
                    HStack {
                        Text("Established:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatDate(createdAt))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                if let updatedAt = company.updatedAt {
                    HStack {
                        Text("Last Updated:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatDate(updatedAt))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                HStack {
                    Text("Status:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(company.verified ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(company.verified ? "Verified" : "Pending Verification")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(company.verified ? .green : .orange)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                // Handle booking
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                    Text("Book Service")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                )
            }
            
            Button(action: {
                // Handle view details
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Details")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Compact Company Card View (for list view)
struct CompactCompanyCardView: View {
    let company: CompanyCard
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Company Logo
            AsyncImage(url: URL(string: company.logoUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Company Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(company.companyName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if company.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                if let rating = company.rating {
                    HStack(spacing: 4) {
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption2)
                            }
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if let reviews = company.reviews {
                            Text("(\(reviews))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let city = company.city {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let serviceTypes = company.serviceTypes, !serviceTypes.isEmpty {
                    Text(serviceTypes.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                // Handle tap
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedCompanyCardView(company: CompanyCard(
            id: "1",
            companyName: "SecureGuard Solutions",
            logoUrl: nil,
            rating: 4.5,
            city: "New York, NY",
            previewImages: [],
            hourlyRate: nil,
            description: nil,
            serviceTypes: ["security_guard", "surveillance", "patrol", "consultation"],
            email: "contact@secureguard.com",
            phone: "+1 (555) 123-4567",
            verified: true,
            reviews: 128,
            createdAt: "2023-01-15T10:30:00.000Z",
            updatedAt: "2024-01-15T10:30:00.000Z"
        ))
        
        CompactCompanyCardView(company: CompanyCard(
            id: "2",
            companyName: "Elite Security Services",
            logoUrl: nil,
            rating: 4.8,
            city: "Los Angeles, CA",
            previewImages: [],
            hourlyRate: nil,
            description: nil,
            serviceTypes: ["security_guard", "drone_patrol"],
            email: "info@elitesecurity.com",
            phone: "+1 (555) 987-6543",
            verified: true,
            reviews: 89,
            createdAt: "2023-03-20T14:15:00.000Z",
            updatedAt: "2024-01-10T09:45:00.000Z"
        ))
    }
    .padding()
    .background(Color(.systemGray6))
}

