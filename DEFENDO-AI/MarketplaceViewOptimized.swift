import SwiftUI
import Combine

// MARK: - Optimized Marketplace View (Swiggy-like Aggregator)
struct MarketplaceViewOptimized: View {
    @StateObject private var aggregatorService = SecurityAggregatorService.shared
    @StateObject private var cartService = SecurityCartService.shared
    @State private var searchQuery = ""
    @State private var selectedFirm: SecurityFirm?
    @State private var showingFirmDetail = false
    @State private var showingCart = false
    
    // Search debouncing
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content
                if aggregatorService.isLoading && aggregatorService.securityFirms.isEmpty {
                    loadingView
                } else if let errorMessage = aggregatorService.errorMessage {
                    errorView(errorMessage)
                } else {
                    securityFirmsList
                }
            }
            .navigationTitle("Security Firms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    cartButton
                }
            }
            .onAppear {
                Task {
                    await aggregatorService.loadSecurityFirms()
                }
            }
            .sheet(isPresented: $showingFirmDetail) {
                if let firm = selectedFirm {
                    SecurityFirmDetailView(firm: firm)
                }
            }
            .sheet(isPresented: $showingCart) {
                SecurityCartView()
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search security firms...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchQuery) { newValue in
                    // Cancel previous search task
                    searchTask?.cancel()
                    
                    // Debounce search
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                        if !Task.isCancelled {
                            await aggregatorService.searchSecurityFirms(query: newValue)
                        }
                    }
                }
            
            if !searchQuery.isEmpty {
                Button("Clear") {
                    searchQuery = ""
                    Task {
                        await aggregatorService.loadSecurityFirms()
                    }
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Cart Button
    private var cartButton: some View {
        Button(action: {
            showingCart = true
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
    
    // MARK: - Loading View
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    SecurityFirmCardSkeleton()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to Load")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task {
                    await aggregatorService.refreshSecurityFirms()
                }
            }
            .controlSize(.regular)
            #if canImport(SwiftUI)
            .buttonStyle(.borderedProminent)
            #endif
        }
        .padding()
    }
    
    // MARK: - Security Firms List
    private var securityFirmsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(aggregatorService.securityFirms) { firm in
                    SecurityFirmCardView(firm: firm)
                        .onTapGesture {
                            selectedFirm = firm
                            showingFirmDetail = true
                        }
                        .onAppear {
                            // Load more when reaching the last item
                            if firm.id == aggregatorService.securityFirms.last?.id {
                                Task {
                                    await aggregatorService.loadMoreSecurityFirms()
                                }
                            }
                        }
                }
                
                // Loading more indicator
                if aggregatorService.isLoading && !aggregatorService.securityFirms.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding()
                }
                
                // No more data indicator
                if !aggregatorService.hasMoreData && !aggregatorService.securityFirms.isEmpty {
                    Text("No more firms to load")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await aggregatorService.refreshSecurityFirms()
        }
    }
}

// MARK: - Company Card View (Enhanced)
struct CompanyCardView: View {
    let company: CompanyCard
    
    var body: some View {
        EnhancedCompanyCardView(company: company)
    }
}

// MARK: - Company Card Skeleton
struct CompanyCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 12)
                }
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 20)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .redacted(reason: .placeholder)
    }
}

// MARK: - Company Detail View
struct CompanyDetailView: View {
    let company: CompanyCard
    @Environment(\.dismiss) private var dismiss
    @State private var services: [ServiceCard] = []
    @State private var isLoadingServices = false
    @State private var serviceError: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Company Header
                    companyHeader
                    
                    // Services Section
                    servicesSection
                }
                .padding()
            }
            .navigationTitle(company.companyName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            loadServices()
        }
    }
    
    private var companyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(company.companyName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let rating = company.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if let hourlyRate = company.hourlyRate {
                        Text("$\(String(format: "%.0f", hourlyRate))/hour")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Spacer()
            }
            
            if let description = company.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoadingServices {
                ProgressView("Loading services...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let error = serviceError {
                Text("Failed to load services: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if services.isEmpty {
                Text("No services available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(services) { service in
                        ServiceRowView(service: service)
                    }
                }
            }
        }
    }
    
    private func loadServices() {
        isLoadingServices = true
        serviceError = nil
        
        Task {
            do {
                // This would call the actual service method
                // For now, we'll create mock data
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                
                let mockServices = company.serviceTypes?.enumerated().map { index, serviceType in
                    ServiceCard(
                        id: "\(company.id)_\(index)",
                        serviceName: serviceType.replacingOccurrences(of: "_", with: " ").capitalized,
                        serviceType: serviceType,
                        price: company.hourlyRate,
                        pricePerHour: company.hourlyRate,
                        currency: "USD",
                        rating: company.rating,
                        providerId: company.id
                    )
                } ?? []
                
                await MainActor.run {
                    self.services = mockServices
                    self.isLoadingServices = false
                }
            } catch {
                await MainActor.run {
                    self.serviceError = error.localizedDescription
                    self.isLoadingServices = false
                }
            }
        }
    }
}

// MARK: - Service Row View
struct ServiceRowView: View {
    let service: ServiceCard
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.serviceName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let description = service.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if let rating = service.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                        }
                    }
                    
                    if let price = service.pricePerHour {
                        Text("$\(String(format: "%.0f", price))/hr")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer()
            
            Button("Book") {
                // Handle booking
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}



#Preview {
    MarketplaceViewOptimized()
}

