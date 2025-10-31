import Foundation
@preconcurrency import Supabase

// MARK: - Service Providers API for Marketplace
extension SupabaseService {

    /// Fetch paginated host profiles for marketplace with optimized query
    func fetchHostProfiles(limit: Int, offset: Int) async throws -> [ServiceDiscoveryViewModel.HostProfile] {
        let response: [HostProfileDTO] = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, logo_path, avatar_url, rating, address, services_offered")
            .order("rating", ascending: false, nullsFirst: false)
            .range(from: offset, to: offset + max(0, limit - 1))
            .execute()
            .value

        return response.map { dto in
            ServiceDiscoveryViewModel.HostProfile(
                id: dto.id,
                company_name: dto.company_name ?? dto.full_name,
                logo_url: dto.logo_path ?? dto.avatar_url,
                rating: dto.rating,
                city: dto.address,
                preview_images: [] // Will be populated when service images are available
            )
        }
    }

    /// Search host profiles by company name or city with optimized query
    func searchHostProfiles(
        matching query: String,
        limit: Int,
        offset: Int
    ) async throws -> [ServiceDiscoveryViewModel.HostProfile] {
        let pattern = "%\(query)%"

        let response: [HostProfileDTO] = try await client
            .from("host_profiles")
            .select("id, company_name, full_name, logo_path, avatar_url, rating, address, services_offered")
            .or("company_name.ilike.\(pattern),full_name.ilike.\(pattern),address.ilike.\(pattern)")
            .order("rating", ascending: false, nullsFirst: false)
            .range(from: offset, to: offset + max(0, limit - 1))
            .execute()
            .value

        return response.map { dto in
            ServiceDiscoveryViewModel.HostProfile(
                id: dto.id,
                company_name: dto.company_name ?? dto.full_name,
                logo_url: dto.logo_path ?? dto.avatar_url,
                rating: dto.rating,
                city: dto.address,
                preview_images: [] // Will be populated when service images are available
            )
        }
    }
}
