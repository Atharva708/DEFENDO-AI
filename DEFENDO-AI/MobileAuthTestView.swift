//
//  MobileAuthTestView.swift
//  DEFENDO-AI
//
//  Test view for mobile number authentication with Twilio
//

import SwiftUI

struct MobileAuthTestView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var authService = AuthService()
    @State private var testPhoneNumber = "+15551234567" // Test number
    @State private var testOTPCode = "123456" // Test OTP
    @State private var showingResults = false
    @State private var testResults: [String] = []
    @State private var isTesting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Mobile Auth Test (Twilio)")
                    .font(.largeTitle)
                    .bold()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Phone Number (E.164 format)")
                        .font(.headline)
                    
                    TextField("Enter test phone number", text: $testPhoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test OTP Code")
                        .font(.headline)
                    
                    TextField("Enter test OTP", text: $testOTPCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                VStack(spacing: 12) {
                    Button("Test OTP Send") {
                        Task {
                            await testOTPSend()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authViewModel.isSendingOTP || isTesting)
                    
                    Button("Test OTP Verify") {
                        Task {
                            await testOTPVerify()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authViewModel.isVerifying || isTesting)
                    
                    Button("Test AuthService Integration") {
                        Task {
                            await testAuthServiceIntegration()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting)
                    
                    Button("Test Real Phone Number") {
                        Task {
                            await testRealPhoneNumber()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting)
                }
                
                if showingResults {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Results:")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(testResults, id: \.self) { result in
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Mobile Auth Test")
        }
    }
    
    private func testOTPSend() async {
        isTesting = true
        authViewModel.phoneNumber = testPhoneNumber
        await authViewModel.startOTP()
        
        addTestResult("OTP Send Test:")
        addTestResult("- Phone: \(testPhoneNumber)")
        addTestResult("- Success: \(authViewModel.successMessage ?? "None")")
        addTestResult("- Error: \(authViewModel.errorMessage ?? "None")")
        addTestResult("- OTP Overlay Shown: \(authViewModel.showOTPOverlay)")
        showingResults = true
        isTesting = false
    }
    
    private func testOTPVerify() async {
        isTesting = true
        authViewModel.phoneNumber = testPhoneNumber
        authViewModel.otpCode = testOTPCode
        await authViewModel.verifyOTP()
        
        addTestResult("OTP Verify Test:")
        addTestResult("- Phone: \(testPhoneNumber)")
        addTestResult("- OTP: \(testOTPCode)")
        addTestResult("- Success: \(authViewModel.successMessage ?? "None")")
        addTestResult("- Error: \(authViewModel.errorMessage ?? "None")")
        addTestResult("- Logged In: \(authViewModel.isLoggedIn)")
        showingResults = true
        isTesting = false
    }
    
    private func testAuthServiceIntegration() async {
        isTesting = true
        addTestResult("AuthService Integration Test:")
        
        do {
            try await authService.requestOTP(phone: testPhoneNumber)
            addTestResult("- OTP Request: Success")
            
            try await authService.verifyOTP(phone: testPhoneNumber, code: testOTPCode)
            addTestResult("- OTP Verify: Success")
            addTestResult("- Authenticated: \(authService.isAuthenticated)")
            addTestResult("- Current User: \(authService.currentUser?.name ?? "None")")
        } catch {
            addTestResult("- Error: \(error.localizedDescription)")
        }
        
        showingResults = true
        isTesting = false
    }
    
    private func testRealPhoneNumber() async {
        isTesting = true
        addTestResult("Real Phone Number Test:")
        addTestResult("- Note: This will send a real SMS via Twilio")
        addTestResult("- Use a real phone number to test")
        addTestResult("- Check your phone for the OTP")
        
        // You can uncomment this to test with real numbers
        /*
        do {
            try await authService.requestOTP(phone: testPhoneNumber)
            addTestResult("- Real OTP sent successfully")
        } catch {
            addTestResult("- Real OTP error: \(error.localizedDescription)")
        }
        */
        
        showingResults = true
        isTesting = false
    }
    
    private func addTestResult(_ result: String) {
        testResults.append("\(Date().formatted(date: .omitted, time: .shortened)): \(result)")
    }
}

#Preview {
    MobileAuthTestView()
}
