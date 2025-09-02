//
//  MarketplaceView.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/8/25.
//

import SwiftUI

enum ActiveSheet: Identifiable {
    case filters, booking(MarketplaceProvider)
    var id: String {
        switch self {
        case .filters: return "filters"
        case .booking(let provider): return provider.id
        }
    }
}

struct MarketplaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory = "Guards"
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet? = nil
    
    let categories = ["Guards", "Drones", "Studios", "Agencies"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 15) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search providers...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Category Toggle
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(categories, id: \.self) { category in
                                Button(category) {
                                    selectedCategory = category
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color.white)
                
                // Provider List
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(getProviders(for: selectedCategory), id: \.id) { provider in
                            ProviderListingCard(provider: provider, onBookNow: { selectedProvider in
                                activeSheet = .booking(selectedProvider)
                            })
                            .environmentObject(appState)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Marketplace")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Filters") {
                activeSheet = .filters
            })
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .filters:
                    FilterView()
                case .booking(_):
                    BookingFlowView()
                        .environmentObject(appState)
                        .environmentObject(AuthService())
                }
            }
        }
    }
    
    private func getProviders(for category: String) -> [MarketplaceProvider] {
        // Mock data - in real app this would come from API
        switch category {
        case "Guards":
            return [
                MarketplaceProvider(id: "1", name: "Elite Security Services", rating: 4.8, reviews: 156, distance: "0.3 miles", price: "$25/hr", image: "person.2.fill", tags: ["Event Guard", "Night Patrol"], verified: true),
                MarketplaceProvider(id: "2", name: "Guardian Protection", rating: 4.6, reviews: 89, distance: "0.8 miles", price: "$30/hr", image: "person.2.fill", tags: ["Corporate", "Residential"], verified: true),
                MarketplaceProvider(id: "3", name: "SafeZone Security", rating: 4.9, reviews: 234, distance: "1.2 miles", price: "$28/hr", image: "person.2.fill", tags: ["VIP Protection", "Event Security"], verified: false)
            ]
        case "Drones":
            return [
                MarketplaceProvider(id: "4", name: "SkyWatch Drones", rating: 4.9, reviews: 89, distance: "0.8 miles", price: "$35/hr", image: "eye.fill", tags: ["Thermal Imaging", "Live Feed"], verified: true),
                MarketplaceProvider(id: "5", name: "Aerial Security", rating: 4.7, reviews: 67, distance: "1.5 miles", price: "$40/hr", image: "eye.fill", tags: ["Night Vision", "Wide Coverage"], verified: true),
                MarketplaceProvider(id: "6", name: "Drone Patrol Pro", rating: 4.5, reviews: 45, distance: "2.1 miles", price: "$32/hr", image: "eye.fill", tags: ["Real-time Alerts", "HD Video"], verified: false)
            ]
        case "Studios":
            return [
                MarketplaceProvider(id: "7", name: "SecureNow Studios", rating: 4.8, reviews: 123, distance: "0.5 miles", price: "$45/hr", image: "building.2.fill", tags: ["Full Service", "24/7"], verified: true),
                MarketplaceProvider(id: "8", name: "Guardian Studios", rating: 4.6, reviews: 78, distance: "1.8 miles", price: "$50/hr", image: "building.2.fill", tags: ["Premium", "Custom"], verified: true)
            ]
        case "Agencies":
            return [
                MarketplaceProvider(id: "9", name: "National Security Agency", rating: 4.9, reviews: 456, distance: "0.2 miles", price: "$60/hr", image: "building.fill", tags: ["Government", "High Security"], verified: true),
                MarketplaceProvider(id: "10", name: "Metro Security Group", rating: 4.7, reviews: 234, distance: "1.0 miles", price: "$55/hr", image: "building.fill", tags: ["Corporate", "Event"], verified: true)
            ]
        default:
            return []
        }
    }
}

struct MarketplaceProvider: Identifiable, Codable {
    let id: String
    let name: String
    let rating: Double
    let reviews: Int
    let distance: String
    let price: String
    let image: String
    let tags: [String]
    let verified: Bool
}

struct ProviderListingCard: View {
    let provider: MarketplaceProvider
    let onBookNow: ((MarketplaceProvider) -> Void)?
    @EnvironmentObject var appState: AppState
    
    init(provider: MarketplaceProvider, onBookNow: ((MarketplaceProvider) -> Void)? = nil) {
        self.provider = provider
        self.onBookNow = onBookNow
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: provider.image)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(provider.name)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if provider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", provider.rating))
                            .font(.caption)
                        Text("(\(provider.reviews) reviews)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(provider.price)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(provider.distance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(provider.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Action Button
            Button("Book Now") {
                onBookNow?(provider)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FilterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var minRating = 4.0
    @State private var maxPrice = 50.0
    @State private var verifiedOnly = false
    @State private var selectedTags: Set<String> = []
    
    let availableTags = ["Event Guard", "Night Patrol", "Corporate", "Residential", "VIP Protection", "Thermal Imaging", "Live Feed", "Night Vision", "Wide Coverage", "Real-time Alerts", "HD Video", "Full Service", "24/7", "Premium", "Custom", "Government", "High Security"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Rating Filter
                VStack(alignment: .leading, spacing: 10) {
                    Text("Minimum Rating")
                        .font(.headline)
                    
                    HStack {
                        Text("0")
                        Slider(value: $minRating, in: 0...5, step: 0.1)
                        Text("5")
                        Text(String(format: "%.1f", minRating))
                            .fontWeight(.medium)
                    }
                }
                
                // Price Filter
                VStack(alignment: .leading, spacing: 10) {
                    Text("Maximum Price")
                        .font(.headline)
                    
                    HStack {
                        Text("$0")
                        Slider(value: $maxPrice, in: 0...100, step: 5)
                        Text("$100")
                        Text("$\(Int(maxPrice))")
                            .fontWeight(.medium)
                    }
                }
                
                // Verified Only
                Toggle("Verified Providers Only", isOn: $verifiedOnly)
                    .font(.headline)
                
                // Tags Filter
                VStack(alignment: .leading, spacing: 10) {
                    Text("Service Tags")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(availableTags, id: \.self) { tag in
                            Button(tag) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTags.contains(tag) ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                            .cornerRadius(8)
                            .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                // Apply Button
                Button("Apply Filters") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Reset") {
                    minRating = 4.0
                    maxPrice = 50.0
                    verifiedOnly = false
                    selectedTags.removeAll()
                },
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}


#Preview {
    MarketplaceView()
        .environmentObject(AppState())
}
