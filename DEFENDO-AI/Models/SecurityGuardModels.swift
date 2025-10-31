//
//  SecurityGuardModels.swift
//  DEFENDO-AI
//
//  Created for Swiggy-like aggregator architecture
//  Security firms as restaurants, guards as dishes
//

import Foundation
import SwiftUI

// MARK: - Security Guard Model (like dishes in Swiggy)
struct SecurityGuard: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let companyId: String
    let companyName: String
    let profileImageUrl: String?
    let rating: Double?
    let experience: Int? // years of experience
    let hourlyRate: Double
    let currency: String
    let specializations: [String]
    let certifications: [String]
    let languages: [String]
    let availability: GuardAvailability
    let location: String?
    let description: String?
    let isVerified: Bool
    let totalBookings: Int?
    let responseTime: Int? // in minutes
    let equipment: [String]
    let shiftPreferences: [String] // day, night, weekend
    let createdAt: String?
    let updatedAt: String?
    
    init(
        id: String,
        name: String,
        companyId: String,
        companyName: String,
        profileImageUrl: String? = nil,
        rating: Double? = nil,
        experience: Int? = nil,
        hourlyRate: Double,
        currency: String = "USD",
        specializations: [String] = [],
        certifications: [String] = [],
        languages: [String] = [],
        availability: GuardAvailability = .available,
        location: String? = nil,
        description: String? = nil,
        isVerified: Bool = false,
        totalBookings: Int? = nil,
        responseTime: Int? = nil,
        equipment: [String] = [],
        shiftPreferences: [String] = [],
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.companyId = companyId
        self.companyName = companyName
        self.profileImageUrl = profileImageUrl
        self.rating = rating
        self.experience = experience
        self.hourlyRate = hourlyRate
        self.currency = currency
        self.specializations = specializations
        self.certifications = certifications
        self.languages = languages
        self.availability = availability
        self.location = location
        self.description = description
        self.isVerified = isVerified
        self.totalBookings = totalBookings
        self.responseTime = responseTime
        self.equipment = equipment
        self.shiftPreferences = shiftPreferences
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Guard Availability
enum GuardAvailability: String, CaseIterable, Codable, Sendable {
    case available = "available"
    case busy = "busy"
    case offline = "offline"
    case onDuty = "on_duty"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .busy: return "Busy"
        case .offline: return "Offline"
        case .onDuty: return "On Duty"
        }
    }
    
    var color: Color {
        switch self {
        case .available: return .green
        case .busy: return .orange
        case .offline: return .gray
        case .onDuty: return .blue
        }
    }
}

// MARK: - Security Firm Model (like restaurants in Swiggy)
struct SecurityFirm: Identifiable, Codable, Sendable {
    let id: String
    let companyName: String
    let logoUrl: String?
    let rating: Double?
    let totalReviews: Int?
    let location: String?
    let address: String?
    let phone: String?
    let email: String?
    let website: String?
    let description: String?
    let servicesOffered: [String]
    let isVerified: Bool
    let isActive: Bool
    let deliveryTime: Int? // estimated response time in minutes
    let minimumOrder: Double? // minimum booking amount
    let deliveryFee: Double?
    let currency: String
    let operatingHours: OperatingHours?
    let coverageArea: [String]
    let certifications: [String]
    let insuranceInfo: String?
    let licenseNumber: String?
    let totalGuards: Int?
    let availableGuards: Int?
    let createdAt: String?
    let updatedAt: String?
    
    init(
        id: String,
        companyName: String,
        logoUrl: String? = nil,
        rating: Double? = nil,
        totalReviews: Int? = nil,
        location: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        description: String? = nil,
        servicesOffered: [String] = [],
        isVerified: Bool = false,
        isActive: Bool = true,
        deliveryTime: Int? = nil,
        minimumOrder: Double? = nil,
        deliveryFee: Double? = nil,
        currency: String = "USD",
        operatingHours: OperatingHours? = nil,
        coverageArea: [String] = [],
        certifications: [String] = [],
        insuranceInfo: String? = nil,
        licenseNumber: String? = nil,
        totalGuards: Int? = nil,
        availableGuards: Int? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.companyName = companyName
        self.logoUrl = logoUrl
        self.rating = rating
        self.totalReviews = totalReviews
        self.location = location
        self.address = address
        self.phone = phone
        self.email = email
        self.website = website
        self.description = description
        self.servicesOffered = servicesOffered
        self.isVerified = isVerified
        self.isActive = isActive
        self.deliveryTime = deliveryTime
        self.minimumOrder = minimumOrder
        self.deliveryFee = deliveryFee
        self.currency = currency
        self.operatingHours = operatingHours
        self.coverageArea = coverageArea
        self.certifications = certifications
        self.insuranceInfo = insuranceInfo
        self.licenseNumber = licenseNumber
        self.totalGuards = totalGuards
        self.availableGuards = availableGuards
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Operating Hours
struct OperatingHours: Codable, Sendable {
    let monday: DayHours?
    let tuesday: DayHours?
    let wednesday: DayHours?
    let thursday: DayHours?
    let friday: DayHours?
    let saturday: DayHours?
    let sunday: DayHours?
    
    init(
        monday: DayHours? = nil,
        tuesday: DayHours? = nil,
        wednesday: DayHours? = nil,
        thursday: DayHours? = nil,
        friday: DayHours? = nil,
        saturday: DayHours? = nil,
        sunday: DayHours? = nil
    ) {
        self.monday = monday
        self.tuesday = tuesday
        self.wednesday = wednesday
        self.thursday = thursday
        self.friday = friday
        self.saturday = saturday
        self.sunday = sunday
    }
}

struct DayHours: Codable, Sendable {
    let open: String // "09:00"
    let close: String // "17:00"
    let isOpen: Bool
    
    init(open: String, close: String, isOpen: Bool = true) {
        self.open = open
        self.close = close
        self.isOpen = isOpen
    }
}

// MARK: - Cart Item (like food items in Swiggy cart)
struct SecurityCartItem: Identifiable, Codable, Sendable {
    let id: String
    let securityGuard: SecurityGuard
    let quantity: Int // number of hours
    let selectedDate: Date
    let selectedTimeSlot: TimeSlot
    let specialInstructions: String?
    let totalPrice: Double
    
    init(
        id: String,
        securityGuard: SecurityGuard,
        quantity: Int,
        selectedDate: Date,
        selectedTimeSlot: TimeSlot,
        specialInstructions: String? = nil
    ) {
        self.id = id
        self.securityGuard = securityGuard
        self.quantity = quantity
        self.selectedDate = selectedDate
        self.selectedTimeSlot = selectedTimeSlot
        self.specialInstructions = specialInstructions
        self.totalPrice = Double(quantity) * securityGuard.hourlyRate
    }
}

// MARK: - Time Slot
struct TimeSlot: Codable, Sendable {
    let startTime: String // "09:00"
    let endTime: String // "17:00"
    let isAvailable: Bool
    
    init(startTime: String, endTime: String, isAvailable: Bool = true) {
        self.startTime = startTime
        self.endTime = endTime
        self.isAvailable = isAvailable
    }
}

// MARK: - Cart Summary
struct SecurityCartSummary: Codable, Sendable {
    let items: [SecurityCartItem]
    let subtotal: Double
    let serviceFee: Double
    let totalAmount: Double
    let currency: String
    let estimatedDeliveryTime: Int? // in minutes
    
    init(
        items: [SecurityCartItem],
        serviceFee: Double = 0.0,
        currency: String = "USD"
    ) {
        self.items = items
        self.subtotal = items.reduce(0) { $0 + $1.totalPrice }
        self.serviceFee = serviceFee
        self.totalAmount = subtotal + serviceFee
        self.currency = currency
        self.estimatedDeliveryTime = nil
    }
}

// MARK: - Database Row Models for Supabase

// Employee row from Supabase employees table
nonisolated(unsafe) struct SecurityEmployeeRow: Codable, Sendable {
    let id: String
    let company_id: String
    let name: String
    let profile_image_url: String?
    let rating: Double?
    let experience_years: Int?
    let hourly_rate: Double
    let currency: String?
    let specializations: [String]?
    let certifications: [String]?
    let languages: [String]?
    let availability: String?
    let location: String?
    let description: String?
    let is_verified: Bool?
    let total_bookings: Int?
    let response_time_minutes: Int?
    let equipment: [String]?
    let shift_preferences: [String]?
    let created_at: String?
    let updated_at: String?
}

// Enhanced host profile row for security firms
nonisolated(unsafe) struct SecurityFirmRow: Codable, Sendable {
    let id: String
    let company_name: String?
    let logo_path: String?
    let avatar_url: String?
    let rating: Double?
    let total_reviews: Int?
    let address: String?
    let phone: String?
    let email: String?
    let website: String?
    let description: String?
    let services_offered: [String]?
    let verified: Bool?
    let is_active: Bool?
    let delivery_time_minutes: Int?
    let minimum_order: Double?
    let delivery_fee: Double?
    let currency: String?
    let operating_hours: String? // JSON string
    let coverage_area: [String]?
    let certifications: [String]?
    let insurance_info: String?
    let license_number: String?
    let total_guards: Int?
    let available_guards: Int?
    let created_at: String?
    let updated_at: String?
}

