//
//  AuthenticationViews.swift
//  DEFENDO-AI
//
//  Created by Atharva Gour on 8/11/25.
//

import SwiftUI

// MARK: - Authentication Container View
struct AuthenticationContainerView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSignUp = false
    @State private var showingLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App Logo and Title
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("SecureNow")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Your AI-powered security companion")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Features Preview
                    VStack(spacing: 15) {
                        FeatureRow(icon: "location.fill", title: "Real-time Location Tracking", description: "Stay safe with live location monitoring")
                        FeatureRow(icon: "exclamationmark.triangle.fill", title: "Instant SOS Alerts", description: "Emergency response at your fingertips")
                        FeatureRow(icon: "person.2.fill", title: "Professional Security", description: "Connect with verified security providers")
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        Button("Get Started") {
                            showingSignUp = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button("I already have an account") {
                            showingLogin = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(authService)
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showingPasswordReset = false
    @State private var showingSignUp = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 15) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Welcome Back")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Sign in to your SecureNow account")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .password)
                            }
                            
                            // Forgot Password
                            HStack {
                                Spacer()
                                Button("Forgot Password?") {
                                    showingPasswordReset = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Error/Success Messages
                        if let error = authService.authError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 30)
                        }
                        
                        if let success = authService.authSuccess {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 30)
                        }
                        
                        // Sign In Button
                        Button("Sign In") {
                            Task {
                                await authService.signIn(email: email, password: password)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                        .padding(.horizontal, 30)
                        
                        // Sign Up Link
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            
                            Button("Sign Up") {
                                showingSignUp = true
                            }
                            .foregroundColor(.blue)
                        }
                        .font(.body)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authService)
        }
        .onAppear {
            // Clear any stale auth error/success messages when opening the login sheet
            authService.clearMessages()
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                appState.currentScreen = .dashboard
                dismiss()
            }
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingLogin = false
    @State private var agreedToTerms = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, phone, password, confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 15) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Create Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Join SecureNow for enhanced security")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your full name", text: $name)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .name)
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                            }
                            
                            // Phone Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone Number")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter your phone number", text: $phone)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.phonePad)
                                    .focused($focusedField, equals: .phone)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                SecureField("Create a password", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .password)
                            }
                            
                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .confirmPassword)
                            }
                            
                            // Terms Agreement
                            HStack(alignment: .top, spacing: 12) {
                                Button(action: {
                                    agreedToTerms.toggle()
                                }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreedToTerms ? .blue : .gray)
                                        .font(.title3)
                                }
                                
                                Text("I agree to the Terms of Service and Privacy Policy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Error/Success Messages
                        if let error = authService.authError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 30)
                        }
                        
                        if let success = authService.authSuccess {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 30)
                        }
                        
                        // Sign Up Button
                        Button("Create Account") {
                            Task {
                                await authService.signUp(email: email, password: password, name: name, phone: phone)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(authService.isLoading || !isFormValid)
                        .padding(.horizontal, 30)
                        
                        // Sign In Link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            
                            Button("Sign In") {
                                showingLogin = true
                            }
                            .foregroundColor(.blue)
                        }
                        .font(.body)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(authService)
        }
        .onAppear {
            // Clear any stale auth error/success messages when opening the signup sheet
            authService.clearMessages()
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                appState.currentScreen = .dashboard
                dismiss()
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !phone.isEmpty && 
        !password.isEmpty && password == confirmPassword && 
        password.count >= 6 && agreedToTerms
    }
}

// MARK: - Password Reset View
struct PasswordResetView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Reset Password")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Enter your email to receive a password reset link")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .focused($isEmailFocused)
                    }
                    .padding(.horizontal, 30)
                    
                    // Error/Success Messages
                    if let error = authService.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                    }
                    
                    if let success = authService.authSuccess {
                        Text(success)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 30)
                    }
                    
                    // Reset Button
                    Button("Send Reset Link") {
                        Task {
                            await authService.resetPassword(email: email)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(authService.isLoading || email.isEmpty)
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

#Preview {
    AuthenticationContainerView()
        .environmentObject(AuthService())
}

