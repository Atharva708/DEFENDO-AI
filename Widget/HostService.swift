// HostService.swift
// Shared model for both app and widget extension

import Foundation

public struct HostService: Identifiable, Codable {
    public let id: String
    public let service_name: String
    public let price: Double?
    public let price_per_hour: Double?
    public let currency: String?
    public let rating: Double?
    public let city: String?
    public let service_type: String?
    public let description: String?
    public let specializations: [String]?
    public let equipment_included: [String]?
    public let images: [String]?
    public let is_active: Bool?
    public let total_bookings: Int?
    
    public init(id: String, service_name: String, price: Double?, price_per_hour: Double?, currency: String?, rating: Double?, city: String?, service_type: String?, description: String?, specializations: [String]?, equipment_included: [String]?, images: [String]?, is_active: Bool?, total_bookings: Int?) {
        self.id = id
        self.service_name = service_name
        self.price = price
        self.price_per_hour = price_per_hour
        self.currency = currency
        self.rating = rating
        self.city = city
        self.service_type = service_type
        self.description = description
        self.specializations = specializations
        self.equipment_included = equipment_included
        self.images = images
        self.is_active = is_active
        self.total_bookings = total_bookings
    }
}
