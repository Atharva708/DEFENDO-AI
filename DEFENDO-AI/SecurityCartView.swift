//
//  SecurityCartView.swift
//  DEFENDO-AI
//
//  Cart view for security guard bookings (like Swiggy cart)
//

import SwiftUI

// MARK: - Security Cart View
struct SecurityCartView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cartService = SecurityCartService.shared
    @State private var showingCheckout = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if cartService.isCartEmpty {
                    emptyCartView
                } else {
                    cartContentView
                }
            }
            .navigationTitle("Security Cart")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Cart View
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Your cart is empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add security guards to your cart to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Browse Guards") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Cart Content View
    private var cartContentView: some View {
        VStack(spacing: 0) {
            // Cart Items
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(cartService.cartItems) { item in
                        CartItemView(item: item)
                    }
                }
                .padding()
            }
            
            // Cart Summary
            cartSummaryView
        }
    }
    
    // MARK: - Cart Summary View
    private var cartSummaryView: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                // Subtotal
                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                    Spacer()
                    Text("$\(String(format: "%.2f", cartService.totalAmount - 5.0))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // Service Fee
                HStack {
                    Text("Service Fee")
                        .font(.subheadline)
                    Spacer()
                    Text("$5.00")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Divider()
                
                // Total
                HStack {
                    Text("Total")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text("$\(String(format: "%.2f", cartService.totalAmount))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            // Checkout Button
            Button(action: {
                showingCheckout = true
            }) {
                HStack {
                    Text("Proceed to Checkout")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", cartService.totalAmount))")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingCheckout) {
            SecurityCheckoutView()
        }
    }
}

// MARK: - Cart Item View
struct CartItemView: View {
    let item: SecurityCartItem
    @StateObject private var cartService = SecurityCartService.shared
    @State private var quantity: Int
    
    init(item: SecurityCartItem) {
        self.item = item
        self._quantity = State(initialValue: item.quantity)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Guard Profile Image
            AsyncImage(url: URL(string: item.securityGuard.profileImageUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Guard Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.securityGuard.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(item.securityGuard.companyName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Date and time
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formatDate(item.selectedDate))
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(item.selectedTimeSlot.startTime) - \(item.selectedTimeSlot.endTime)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
                
                // Special instructions
                if let instructions = item.specialInstructions, !instructions.isEmpty {
                    Text("Note: \(instructions)")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Quantity and Price
            VStack(alignment: .trailing, spacing: 8) {
                // Quantity selector
                HStack(spacing: 8) {
                    Button(action: {
                        if quantity > 1 {
                            quantity -= 1
                            cartService.updateGuardQuantity(guardId: item.securityGuard.id, newQuantity: quantity)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.caption)
                            .foregroundColor(quantity <= 1 ? .secondary : .primary)
                    }
                    .disabled(quantity <= 1)
                    
                    Text("\(quantity)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minWidth: 20)
                    
                    Button(action: {
                        quantity += 1
                        cartService.updateGuardQuantity(guardId: item.securityGuard.id, newQuantity: quantity)
                    }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(6)
                
                // Price
                Text("$\(String(format: "%.2f", item.totalPrice))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                
                // Remove button
                Button(action: {
                    cartService.removeGuardFromCart(guardId: item.securityGuard.id)
                }) {
                    Text("Remove")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Security Checkout View
struct SecurityCheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cartService = SecurityCartService.shared
    @State private var selectedPaymentMethod = "card"
    @State private var showingPaymentMethods = false
    @State private var isProcessing = false
    @State private var showingSuccess = false
    
    private let paymentMethods = ["card", "apple_pay", "google_pay", "paypal"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Booking Summary
                    bookingSummarySection
                    
                    // Payment Method
                    paymentMethodSection
                    
                    // Terms and Conditions
                    termsSection
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Booking Confirmed!", isPresented: $showingSuccess) {
                Button("OK") {
                    cartService.clearCart()
                    dismiss()
                }
            } message: {
                Text("Your security guard booking has been confirmed. You will receive a confirmation email shortly.")
            }
        }
    }
    
    // MARK: - Booking Summary Section
    private var bookingSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Booking Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(cartService.cartItems, id: \.id) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.securityGuard.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(item.quantity) hours • \(formatDate(item.selectedDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", item.totalPrice))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            HStack {
                Text("Total")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("$\(String(format: "%.2f", cartService.totalAmount))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Payment Method Section
    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Method")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showingPaymentMethods = true
            }) {
                HStack {
                    Image(systemName: getPaymentMethodIcon(selectedPaymentMethod))
                        .font(.title2)
                    
                    Text(getPaymentMethodName(selectedPaymentMethod))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .foregroundColor(.primary)
        }
        .sheet(isPresented: $showingPaymentMethods) {
            PaymentMethodPickerSheet(selectedMethod: $selectedPaymentMethod)
        }
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terms & Conditions")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("By proceeding with this booking, you agree to our terms of service and privacy policy. Security guards will arrive at the scheduled time and location.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                processBooking()
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Confirm Booking")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isProcessing ? Color.gray : Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func getPaymentMethodIcon(_ method: String) -> String {
        switch method {
        case "card": return "creditcard"
        case "apple_pay": return "applelogo"
        case "google_pay": return "g.circle"
        case "paypal": return "p.circle"
        default: return "creditcard"
        }
    }
    
    private func getPaymentMethodName(_ method: String) -> String {
        switch method {
        case "card": return "Credit/Debit Card"
        case "apple_pay": return "Apple Pay"
        case "google_pay": return "Google Pay"
        case "paypal": return "PayPal"
        default: return "Credit/Debit Card"
        }
    }
    
    private func processBooking() {
        isProcessing = true
        
        // Simulate booking processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
            showingSuccess = true
        }
    }
}

// MARK: - Payment Method Picker Sheet
struct PaymentMethodPickerSheet: View {
    @Binding var selectedMethod: String
    @Environment(\.dismiss) private var dismiss
    
    private let paymentMethods = [
        ("card", "Credit/Debit Card", "creditcard"),
        ("apple_pay", "Apple Pay", "applelogo"),
        ("google_pay", "Google Pay", "g.circle"),
        ("paypal", "PayPal", "p.circle")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                LazyVStack(spacing: 8) {
                    ForEach(paymentMethods, id: \.0) { method in
                        Button(action: {
                            selectedMethod = method.0
                        }) {
                            HStack {
                                Image(systemName: method.2)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                
                                Text(method.1)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if selectedMethod == method.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedMethod == method.0 ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                            )
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
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
    SecurityCartView()
}

