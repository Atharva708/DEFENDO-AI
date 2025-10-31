import Foundation

/// DTO that mirrors the host_profiles table columns we use
nonisolated(unsafe) struct HostProfileDTO: Identifiable, Sendable {
    let id: String
    let email: String
    let full_name: String
    let company_name: String?
    let avatar_url: String?
    let phone: String?
    let address: String?
    let services_offered: [String]?
    let verified: Bool?
    let rating: Double?
    let reviews: Int?
    let created_at: String?
    let updated_at: String?
    let logo_path: String?
}

// Provide explicit nonisolated Codable conformance so decoding can occur off the main actor safely
nonisolated extension HostProfileDTO: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case full_name
        case company_name
        case avatar_url
        case phone
        case address
        case services_offered
        case verified
        case rating
        case reviews
        case created_at
        case updated_at
        case logo_path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        full_name = try container.decode(String.self, forKey: .full_name)
        company_name = try container.decodeIfPresent(String.self, forKey: .company_name)
        avatar_url = try container.decodeIfPresent(String.self, forKey: .avatar_url)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        services_offered = try container.decodeIfPresent([String].self, forKey: .services_offered)
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        reviews = try container.decodeIfPresent(Int.self, forKey: .reviews)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        logo_path = try container.decodeIfPresent(String.self, forKey: .logo_path)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(full_name, forKey: .full_name)
        try container.encodeIfPresent(company_name, forKey: .company_name)
        try container.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(services_offered, forKey: .services_offered)
        try container.encodeIfPresent(verified, forKey: .verified)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(reviews, forKey: .reviews)
        try container.encodeIfPresent(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(logo_path, forKey: .logo_path)
    }
}
