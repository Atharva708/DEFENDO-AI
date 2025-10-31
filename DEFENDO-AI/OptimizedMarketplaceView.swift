//
//  OptimizedMarketplaceView.swift
//  DEFENDO-AI
//
//  Optimized marketplace view with improved performance
//

import SwiftUI
import Combine

struct OptimizedMarketplaceView: View {
    @StateObject private var marketplaceService = OptimizedMarketplaceService.shared
    @State private var searchQuery = ""
    @State private var selectedFirm: SecurityFirm?
    @State private var showingFirmDetail = false
    @State private var showingCart = false
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content
                if marketplaceService.isLoading && marketplaceService.securityFirms.isEmpty {
                    loadingView
                } else if let errorMessage = marketplaceService.errorMessage {
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
                    await marketplaceService.loadSecurityFirms(refresh: true)
                }
            }
            .refreshable {
                await marketplaceService.loadSecurityFirms(refresh: true)
            }
            .sheet(isPresented: $showingFirmDetail) {
                if let firm = selectedFirm {
                    OptimizedSecurityFirmDetailView(firm: firm)
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
                            if newValue.isEmpty {
                                await marketplaceService.loadSecurityFirms(refresh: true)
                            } else {
                                await marketplaceService.searchSecurityFirms(query: newValue)
                            }
                        }
                    }
                }
            
            if !searchQuery.isEmpty {
                Button("Clear") {
                    searchQuery = ""
                    Task {
                        await marketplaceService.loadSecurityFirms(refresh: true)
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
                    .foregroundColor(.primary)
                
                // Cart badge (if you have cart items)
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                    .offset(x: 12, y: -12)
                    .overlay(
                        Text("0") // Replace with actual cart count
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading security firms...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await marketplaceService.loadSecurityFirms(refresh: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Security Firms List
    private var securityFirmsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(marketplaceService.securityFirms) { firm in
                    OptimizedSecurityFirmCard(firm: firm) {
                        selectedFirm = firm
                        showingFirmDetail = true
                    }
                    .onAppear {
                        // Load more when reaching the end
                        if firm.id == marketplaceService.securityFirms.last?.id {
                            Task {
                                await marketplaceService.loadMoreSecurityFirms()
                            }
                        }
                    }
                }
                
                // Loading indicator for pagination
                if marketplaceService.isLoading && !marketplaceService.securityFirms.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Optimized Security Firm Detail View
struct OptimizedSecurityFirmDetailView: View {
    let firm: SecurityFirm
    @StateObject private var marketplaceService = OptimizedMarketplaceService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGuard: SecurityGuard?
    @State private var showingGuardDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Company Header
                    companyHeader
                    
                    // Services Section
                    servicesSection
                    
                    // Security Guards Section
                    securityGuardsSection
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
            }
            .onAppear {
                Task {
                    await marketplaceService.loadSecurityGuards(for: firm.id, refresh: true)
                }
            }
            .sheet(isPresented: $showingGuardDetail) {
                if let selectedGuard = selectedGuard {
                    OptimizedSecurityGuardDetailView(securityGuard: selectedGuard)
                }
            }
        }
    }
    
    // MARK: - Company Header
    private var companyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                OptimizedAsyncImage(urlString: firm.logoUrl) {
                    AnyView(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                    .font(.title)
                            )
                    )
                } content: { image in
                    AnyView(
                        image
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(firm.companyName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let location = firm.location {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let rating = firm.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                }
                
                Spacer()
            }
            
            if let description = firm.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Services Section
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services Offered")
                .font(.headline)
            
            if firm.servicesOffered.isEmpty {
                Text("No services listed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(firm.servicesOffered, id: \.self) { service in
                        Text(service)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Security Guards Section
    private var securityGuardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Guards")
                .font(.headline)
            
            if marketplaceService.isLoading && marketplaceService.securityGuards.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading guards...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if marketplaceService.securityGuards.isEmpty {
                Text("No guards available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(marketplaceService.securityGuards) { securityGuard in
                        OptimizedSecurityGuardCard(securityGuard: securityGuard) {
                            selectedGuard = securityGuard
                            showingGuardDetail = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Optimized Security Guard Detail View
struct OptimizedSecurityGuardDetailView: View {
    let securityGuard: SecurityGuard
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Guard Header
                    guardHeader
                    
                    // Details Section
                    detailsSection
                    
                    // Specializations Section
                    specializationsSection
                    
                    // Contact Section
                    contactSection
                }
                .padding()
            }
            .navigationTitle(securityGuard.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Book") {
                        // Handle booking
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Guard Header
    private var guardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                OptimizedAsyncImage(urlString: securityGuard.profileImageUrl) {
                    AnyView(
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.title)
                            )
                    )
                } content: { image in
                    AnyView(
                        image
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(securityGuard.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = securityGuard.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if let rating = securityGuard.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let experience = securityGuard.experience {
                            Text("\(experience) years exp")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack {
                    Text("₹\(Int(securityGuard.hourlyRate))/hr")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Hourly Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "briefcase.fill", text: securityGuard.experience != nil ? "Experience: \(securityGuard.experience!) years" : "Experience: Not specified")
                DetailRow(icon: "mappin.and.ellipse", text: "Location: \(securityGuard.location ?? "Not specified")")
                DetailRow(icon: "clock.fill", text: "Availability: \(securityGuard.availability.rawValue.capitalized)")
                DetailRow(icon: "coloncurrencysign.circle", text: "Currency: \(securityGuard.currency)")
            }
        }
    }
    
    // MARK: - Specializations Section
    private var specializationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specializations")
                .font(.headline)
            
            if securityGuard.specializations.isEmpty {
                Text("No specializations listed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(securityGuard.specializations, id: \.self) { specialization in
                        Text(specialization)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Contact Section
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(icon: "building.2.fill", text: "Company: \(securityGuard.companyName)")
                if let loc = securityGuard.location, !loc.isEmpty { DetailRow(icon: "phone.fill", text: "Contact: Not provided") }
            }
        }
    }
}


#Preview {
    OptimizedMarketplaceView()
}
