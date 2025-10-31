//
//  SecurityFirmsView.swift
//  DEFENDO-AI
//
//  Swiggy-like marketplace view showing security firms as restaurants
//

import SwiftUI

// MARK: - Security Firms View (Restaurants in Swiggy-like model)
struct SecurityFirmsView: View {
    @State private var firms: [SecurityFirm] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var hasMoreData: Bool = true
    @State private var limit: Int = 20
    @State private var offset: Int = 0

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
                if isLoading && firms.isEmpty {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else {
                    securityFirmsList
                }
            }
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    cartButton
                }
            }
            .onAppear {
                Task {
                    await loadFirms(reset: true)
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
                            if newValue.isEmpty {
                                await loadFirms(reset: true)
                            } else {
                                await searchFirms(query: newValue)
                            }
                        }
                    }
                }
            
            if !searchQuery.isEmpty {
                Button("Clear") {
                    searchQuery = ""
                    Task {
                        await loadFirms(reset: true)
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
                    await loadFirms(reset: true)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
    
    // MARK: - Security Firms List
    private var securityFirmsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(firms) { firm in
                    SecurityFirmCardView(firm: firm)
                        .onTapGesture {
                            selectedFirm = firm
                            showingFirmDetail = true
                        }
                        .onAppear {
                            // Load more when reaching the last item
                            if firm.id == firms.last?.id {
                                Task {
                                    await loadMoreFirms()
                                }
                            }
                        }
                }
                
                // Loading more indicator
                if isLoading && !firms.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding()
                }
                
                // No more data indicator
                if !hasMoreData && !firms.isEmpty {
                    Text("No more firms to load")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await loadFirms(reset: true)
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadFirms(reset: Bool) async {
        await MainActor.run {
            if reset {
                isLoading = true
                errorMessage = nil
                hasMoreData = true
                offset = 0
                firms.removeAll()
            } else {
                isLoading = true
                errorMessage = nil
            }
        }
        do {
            let fetched = try await SupabaseService.shared.fetchSecurityFirms(limit: limit, offset: offset)
            await MainActor.run {
                firms.append(contentsOf: fetched)
                hasMoreData = fetched.count >= limit
                offset += fetched.count
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadMoreFirms() async {
        guard !isLoading, hasMoreData else { return }
        await loadFirms(reset: false)
    }

    private func searchFirms(query: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            hasMoreData = true
            offset = 0
            firms.removeAll()
        }
        do {
            let results = try await SupabaseService.shared.searchSecurityFirms(query: query, limit: limit, offset: 0)
            await MainActor.run {
                firms = results
                hasMoreData = results.count >= limit
                offset = results.count
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Security Firm Card View
struct SecurityFirmCardView: View {
    let firm: SecurityFirm
    @StateObject private var cartService = SecurityCartService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // Company Logo
                AsyncImage(url: URL(string: firm.logoUrl ?? "")) { phase in
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(firm.companyName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        if firm.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    if let rating = firm.rating {
                        HStack(spacing: 4) {
                            HStack(spacing: 1) {
                                ForEach(0..<5, id: \.self) { index in
                                    Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .font(.caption2)
                                }
                            }
                            Text(firm.ratingDisplay)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            if let reviews = firm.totalReviews {
                                Text("(\(reviews))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let location = firm.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Services offered
                    if !firm.servicesOffered.isEmpty {
                        Text(firm.servicesOffered.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Status indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text(firm.availabilityStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(firm.isCurrentlyOpen ? .green : .red)
                    
                    if let deliveryTime = firm.deliveryTime {
                        Text("\(deliveryTime) min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Services Section
            if !firm.servicesOffered.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(firm.servicesOffered.prefix(4), id: \.self) { service in
                            Text(service.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Handle view guards
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                        Text("View Guards")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    // Handle contact
                    if let phone = firm.phone, let url = URL(string: "tel:\(phone)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text("Call")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }
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

// MARK: - Security Firm Card Skeleton
struct SecurityFirmCardSkeleton: View {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .redacted(reason: .placeholder)
    }
}



#Preview {
    SecurityFirmsView()
}

