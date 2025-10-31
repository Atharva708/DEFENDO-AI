//
//  SecurityCartService.swift
//  DEFENDO-AI
//
//  Cart management service for Swiggy-like aggregator
//  Manages security guard cart items and booking flow
//

import Foundation
import Combine

// MARK: - Security Cart Service
@MainActor
class SecurityCartService: ObservableObject {
    static let shared = SecurityCartService()
    
    // MARK: - Published Properties
    @Published var cartItems: [SecurityCartItem] = []
    @Published var selectedFirm: SecurityFirm?
    @Published var isCartEmpty: Bool = true
    @Published var totalItems: Int = 0
    @Published var totalAmount: Double = 0.0
    
    // MARK: - Private Properties
    private let serviceFee: Double = 5.0 // Fixed service fee
    private let currency: String = "USD"
    
    private init() {
        updateCartSummary()
    }
    
    // MARK: - Public Methods
    
    /// Add a security guard to cart
    func addGuardToCart(
        guard: SecurityGuard,
        quantity: Int,
        selectedDate: Date,
        selectedTimeSlot: TimeSlot,
        specialInstructions: String? = nil
    ) {
        let cartItem = SecurityCartItem(
            id: UUID().uuidString,
            securityGuard: `guard`,
            quantity: quantity,
            selectedDate: selectedDate,
            selectedTimeSlot: selectedTimeSlot,
            specialInstructions: specialInstructions
        )
        
        // Check if guard already exists in cart
        if let existingIndex = cartItems.firstIndex(where: { $0.securityGuard.id == `guard`.id }) {
            // Update existing item
            cartItems[existingIndex] = cartItem
        } else {
            // Add new item
            cartItems.append(cartItem)
        }
        
        updateCartSummary()
    }
    
    /// Remove a guard from cart
    func removeGuardFromCart(guardId: String) {
        cartItems.removeAll { $0.securityGuard.id == guardId }
        updateCartSummary()
    }
    
    /// Update guard quantity in cart
    func updateGuardQuantity(guardId: String, newQuantity: Int) {
        guard let index = cartItems.firstIndex(where: { $0.securityGuard.id == guardId }) else { return }
        
        if newQuantity <= 0 {
            removeGuardFromCart(guardId: guardId)
        } else {
            let updatedItem = SecurityCartItem(
                id: cartItems[index].id,
                securityGuard: cartItems[index].securityGuard,
                quantity: newQuantity,
                selectedDate: cartItems[index].selectedDate,
                selectedTimeSlot: cartItems[index].selectedTimeSlot,
                specialInstructions: cartItems[index].specialInstructions
            )
            cartItems[index] = updatedItem
            updateCartSummary()
        }
    }
    
    /// Clear entire cart
    func clearCart() {
        cartItems.removeAll()
        selectedFirm = nil
        updateCartSummary()
    }
    
    /// Set selected security firm
    func setSelectedFirm(_ firm: SecurityFirm) {
        selectedFirm = firm
    }
    
    /// Get cart summary
    func getCartSummary() -> SecurityCartSummary {
        return SecurityCartSummary(
            items: cartItems,
            serviceFee: serviceFee,
            currency: currency
        )
    }
    
    /// Check if guard is already in cart
    func isGuardInCart(guardId: String) -> Bool {
        return cartItems.contains { $0.securityGuard.id == guardId }
    }
    
    /// Get quantity of specific guard in cart
    func getGuardQuantity(guardId: String) -> Int {
        return cartItems.first { $0.securityGuard.id == guardId }?.quantity ?? 0
    }
    
    /// Validate cart before checkout
    func validateCart() -> CartValidationResult {
        if cartItems.isEmpty {
            return .failure("Cart is empty")
        }
        
        if selectedFirm == nil {
            return .failure("No security firm selected")
        }
        
        // Check if all guards are from the same company
        let companyIds = Set(cartItems.map { $0.securityGuard.companyId })
        if companyIds.count > 1 {
            return .failure("All guards must be from the same security firm")
        }
        
        // Check if selected firm matches guard companies
        if let firm = selectedFirm, !companyIds.contains(firm.id) {
            return .failure("Selected firm doesn't match guard companies")
        }
        
        return .success
    }
    
    // MARK: - Private Methods
    
    private func updateCartSummary() {
        isCartEmpty = cartItems.isEmpty
        totalItems = cartItems.reduce(0) { $0 + $1.quantity }
        totalAmount = cartItems.reduce(0) { $0 + $1.totalPrice } + serviceFee
    }
}

// MARK: - Cart Validation Result
enum CartValidationResult {
    case success
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let message):
            return message
        }
    }
}

// MARK: - Cart Extensions
extension SecurityCartService {
    
    /// Get guards grouped by company
    func getGuardsByCompany() -> [String: [SecurityCartItem]] {
        return Dictionary(grouping: cartItems) { $0.securityGuard.companyId }
    }
    
    /// Get total hours for specific company
    func getTotalHoursForCompany(companyId: String) -> Int {
        return cartItems
            .filter { $0.securityGuard.companyId == companyId }
            .reduce(0) { $0 + $1.quantity }
    }
    
    /// Get estimated total time for all services
    func getEstimatedTotalTime() -> Int {
        return cartItems.reduce(0) { $0 + $1.quantity }
    }
    
    /// Check if cart has guards from multiple companies
    func hasMultipleCompanies() -> Bool {
        let companyIds = Set(cartItems.map { $0.securityGuard.companyId })
        return companyIds.count > 1
    }
    
    /// Get primary company (most guards)
    func getPrimaryCompany() -> String? {
        let companyCounts = Dictionary(grouping: cartItems) { $0.securityGuard.companyId }
            .mapValues { $0.reduce(0) { $0 + $1.quantity } }
        
        return companyCounts.max { $0.value < $1.value }?.key
    }
}

