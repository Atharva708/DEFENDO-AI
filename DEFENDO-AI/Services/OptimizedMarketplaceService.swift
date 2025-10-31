//
//  OptimizedMarketplaceService.swift
//  DEFENDO-AI
//
//  Optimized marketplace service with caching and performance improvements
//

import Foundation
import Combine
import SwiftUI

// MARK: - Optimized Marketplace Service
class OptimizedMarketplaceService: ObservableObject {
    static let shared = OptimizedMarketplaceService()
    
    @Published var securityFirms: [SecurityFirm] = []
    @Published var securityGuards: [SecurityGuard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMoreData = true
    
    private let supabaseService = SupabaseService.shared
    private let imageService = ImageLoadingService.shared
    private var currentPage = 0
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func loadSecurityFirms(refresh: Bool = false) async {
        await MainActor.run {
            if refresh {
                self.currentPage = 0
                self.securityFirms.removeAll()
                self.hasMoreData = true
                // Clear cache for security firms
                // Note: Cache will be cleared automatically on refresh
            }
            
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let firms = try await supabaseService.fetchSecurityFirms(
                limit: pageSize,
                offset: currentPage * pageSize
            )
            
            await MainActor.run {
                if refresh {
                    self.securityFirms = firms
                } else {
                    self.securityFirms.append(contentsOf: firms)
                }
                
                self.currentPage += 1
                self.hasMoreData = firms.count == self.pageSize
                self.isLoading = false
            }
            
            // Preload images for the new firms
            let imageUrls = firms.compactMap { $0.logoUrl }
            await imageService.preloadImages(from: imageUrls)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func loadMoreSecurityFirms() async {
        guard !isLoading && hasMoreData else { return }
        await loadSecurityFirms(refresh: false)
    }
    
    func searchSecurityFirms(query: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let firms = try await supabaseService.searchSecurityFirms(query: query)
            
            await MainActor.run {
                self.securityFirms = firms
                self.isLoading = false
            }
            
            // Preload images for search results
            let imageUrls = firms.compactMap { $0.logoUrl }
            await imageService.preloadImages(from: imageUrls)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func loadSecurityGuards(for companyId: String, refresh: Bool = false) async {
        await MainActor.run {
            if refresh {
                self.securityGuards.removeAll()
            }
            
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let guards = try await supabaseService.fetchSecurityGuardsForCompany(companyId: companyId)
            
            await MainActor.run {
                if refresh {
                    self.securityGuards = guards
                } else {
                    self.securityGuards.append(contentsOf: guards)
                }
                
                self.isLoading = false
            }
            
            // Preload images for the guards
            let imageUrls = guards.compactMap { $0.profileImageUrl }
            await imageService.preloadImages(from: imageUrls)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func clearCache() async {
        // Clear cache for all data types
        // Note: Cache will be cleared automatically
        await imageService.clearCache()
        
        await MainActor.run {
            self.securityFirms.removeAll()
            self.securityGuards.removeAll()
            self.currentPage = 0
            self.hasMoreData = true
        }
    }
}

// MARK: - Optimized Security Firm Card
struct OptimizedSecurityFirmCard: View {
    let firm: SecurityFirm
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Company Logo
                HStack {
                    OptimizedAsyncImage(urlString: firm.logoUrl) {
                        AnyView(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "building.2")
                                        .foregroundColor(.gray)
                                )
                        )
                    } content: { image in
                        AnyView(
                            image
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(firm.companyName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if let location = firm.location {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        HStack {
                            if let rating = firm.rating {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("View Details")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
                
                // Services Preview
                if !firm.servicesOffered.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(firm.servicesOffered.prefix(3), id: \.self) { service in
                                Text(service)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                            
                            if firm.servicesOffered.count > 3 {
                                Text("+\(firm.servicesOffered.count - 3) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Optimized Security Guard Card
struct OptimizedSecurityGuardCard: View {
    let securityGuard: SecurityGuard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Image
                OptimizedAsyncImage(urlString: securityGuard.profileImageUrl) {
                    AnyView(
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                    )
                } content: { image in
                    AnyView(
                        image
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(securityGuard.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let description = securityGuard.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        if let rating = securityGuard.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let experience = securityGuard.experience, experience > 0 {
                            Text("\(experience) years exp")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("₹\(Int(securityGuard.hourlyRate))/hr")
                            .font(.caption)
                            .fontWeight(.medium)
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

// MARK: - Performance Monitoring
extension OptimizedMarketplaceService {
    func startPerformanceMonitoring() {
        // Monitor loading times
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.logPerformanceMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func logPerformanceMetrics() {
        if AppConfig.Features.enableDetailedLogging {
            print("[Performance] Security Firms: \(securityFirms.count)")
            print("[Performance] Security Guards: \(securityGuards.count)")
            print("[Performance] Loading: \(isLoading)")
        }
    }
}
