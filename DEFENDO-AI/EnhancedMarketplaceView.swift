//
//  EnhancedMarketplaceView.swift
//  DEFENDO-AI
//
//  Enhanced marketplace view with improved UI and performance
//

import SwiftUI

struct EnhancedMarketplaceView: View {
    @StateObject private var marketplaceService = OptimizedMarketplaceService.shared
    @State private var searchText = ""
    @State private var selectedTab: MarketplaceTab = .companies
    @State private var showingSearchResults = false
    @State private var selectedCompany: SecurityFirm?
    @State private var showingCompanyDetail = false
    
    enum MarketplaceTab: String, CaseIterable {
        case companies = "Companies"
        case guards = "Security Guards"
        
        var icon: String {
            switch self {
            case .companies: return "building.2"
            case .guards: return "person.2"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Search
                headerView
                
                // Tab Selector
                tabSelector
                
                // Content
                contentView
            }
            .navigationTitle("Security Marketplace")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
        }
        .sheet(isPresented: $showingCompanyDetail) {
            if let company = selectedCompany {
                CompanyDetailSheet(company: company)
            }
        }
        .onAppear {
            Task {
                await loadInitialData()
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search companies or guards...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        Task {
                            await performSearch()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        showingSearchResults = false
                        Task {
                            await loadInitialData()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Stats
            statsView
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Stats View
    private var statsView: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "Companies",
                value: "\(marketplaceService.securityFirms.count)",
                icon: "building.2",
                color: .blue
            )
            
            StatCard(
                title: "Guards",
                value: "\(marketplaceService.securityGuards.count)",
                icon: "person.2",
                color: .green
            )
            
            StatCard(
                title: "Available",
                value: "24/7",
                icon: "clock",
                color: .orange
            )
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(MarketplaceTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            if marketplaceService.isLoading && marketplaceService.securityFirms.isEmpty {
                loadingView
            } else if let errorMessage = marketplaceService.errorMessage {
                errorView(errorMessage)
            } else {
                switch selectedTab {
                case .companies:
                    companiesView
                case .guards:
                    guardsView
                }
            }
        }
    }
    
    // MARK: - Companies View
    private var companiesView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(marketplaceService.securityFirms, id: \.id) { company in
                    EnhancedCompanyCard(company: company) {
                        selectedCompany = company
                        showingCompanyDetail = true
                    }
                }
                
                if marketplaceService.hasMoreData && !marketplaceService.isLoading {
                    loadMoreButton
                }
                
                if marketplaceService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .onAppear {
            if marketplaceService.securityFirms.isEmpty {
                Task {
                    await marketplaceService.loadSecurityFirms()
                }
            }
        }
    }
    
    // MARK: - Guards View
    private var guardsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(marketplaceService.securityGuards, id: \.id) { securityGuard in
                    EnhancedGuardCard(securityGuard: securityGuard) {
                        // Handle guard selection
                    }
                }
                
                if marketplaceService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .onAppear {
            if marketplaceService.securityGuards.isEmpty {
                // Load guards for the first company if available
                if let firstCompany = marketplaceService.securityFirms.first {
                    Task {
                        await marketplaceService.loadSecurityGuards(for: firstCompany.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Security Companies...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await refreshData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button("Load More Companies") {
            Task {
                await marketplaceService.loadMoreSecurityFirms()
            }
        }
        .buttonStyle(.bordered)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() async {
        await marketplaceService.loadSecurityFirms()
    }
    
    private func refreshData() async {
        await marketplaceService.loadSecurityFirms(refresh: true)
    }
    
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        showingSearchResults = true
        await marketplaceService.searchSecurityFirms(query: searchText)
    }
}

// MARK: - Enhanced Company Card
struct EnhancedCompanyCard: View {
    let company: SecurityFirm
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 16) {
                    // Logo
                    if let url = company.logoUrl.flatMap(URL.init(string:)) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "building.2")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                            )
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Company Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(company.companyName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if let location = company.location {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Rating
                        if let rating = company.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if let reviews = company.totalReviews {
                                    Text("(\(reviews) reviews)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Arrow
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                // Services
                if !company.servicesOffered.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(company.servicesOffered.prefix(4), id: \.self) { service in
                                ServiceTag(service: service)
                            }
                            
                            if company.servicesOffered.count > 4 {
                                Text("+\(company.servicesOffered.count - 4) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Description
                if let description = company.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Guard Card
struct EnhancedGuardCard: View {
    let securityGuard: SecurityGuard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image
                if let url = securityGuard.profileImageUrl.flatMap(URL.init(string:)) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                }
                
                // Guard Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(securityGuard.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let description = securityGuard.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Stats
                    HStack(spacing: 16) {
                        if let exp = securityGuard.experience, exp > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("\(Int(exp)) years")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let rating = securityGuard.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("₹\(Int(securityGuard.hourlyRate))/hr")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ServiceTag: View {
    let service: String
    
    var body: some View {
        Text(service)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

struct CompanyDetailSheet: View {
    let company: SecurityFirm
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            if let url = company.logoUrl.flatMap(URL.init(string:)) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "building.2")
                                                .foregroundColor(.gray)
                                        )
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "building.2")
                                            .foregroundColor(.gray)
                                    )
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(company.companyName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                if let location = company.location {
                                    Text(location)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let rating = company.rating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text(String(format: "%.1f", rating))
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Services
                    if !company.servicesOffered.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Services Offered")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(company.servicesOffered, id: \.self) { service in
                                    ServiceTag(service: service)
                                }
                            }
                        }
                    }
                    
                    // Description
                    if let description = company.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Company Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EnhancedMarketplaceView()
}

