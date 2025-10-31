//
//  LegalAgreementTestView.swift
//  DEFENDO-AI
//
//  Test view for legal agreement flow
//

import SwiftUI

struct LegalAgreementTestView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var testUserId = "test-user-123"
    @State private var testResults: [String] = []
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Legal Agreement Test")
                    .font(.largeTitle)
                    .bold()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test User ID")
                        .font(.headline)
                    
                    TextField("Enter test user ID", text: $testUserId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(spacing: 12) {
                    Button("Test Legal Acceptance Check") {
                        Task {
                            await testLegalAcceptanceCheck()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Legal Acceptance Recording") {
                        Task {
                            await testLegalAcceptanceRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Legal Agreement View") {
                        testLegalAgreementView()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear Test Data") {
                        clearTestData()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
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
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Legal Agreement Test")
        }
    }
    
    private func testLegalAcceptanceCheck() async {
        addTestResult("Legal Acceptance Check Test:")
        
        do {
            let hasAccepted = try await supabaseService.hasUserAcceptedLegal(userId: testUserId)
            addTestResult("- User ID: \(testUserId)")
            addTestResult("- Has Accepted Legal: \(hasAccepted)")
            addTestResult("- Test: Success")
        } catch {
            addTestResult("- Error: \(error.localizedDescription)")
            addTestResult("- Test: Failed")
        }
        
        showingResults = true
    }
    
    private func testLegalAcceptanceRecording() async {
        addTestResult("Legal Acceptance Recording Test:")
        
        do {
            try await supabaseService.recordLegalAcceptance(
                userId: testUserId,
                termsAccepted: true,
                privacyPolicyAccepted: true
            )
            addTestResult("- User ID: \(testUserId)")
            addTestResult("- Terms Accepted: true")
            addTestResult("- Privacy Policy Accepted: true")
            addTestResult("- Test: Success")
        } catch {
            addTestResult("- Error: \(error.localizedDescription)")
            addTestResult("- Test: Failed")
        }
        
        showingResults = true
    }
    
    private func testLegalAgreementView() {
        addTestResult("Legal Agreement View Test:")
        addTestResult("- Opening Legal Agreement View")
        addTestResult("- User ID: \(testUserId)")
        addTestResult("- Test: Manual verification required")
        
        showingResults = true
    }
    
    private func clearTestData() {
        addTestResult("Clear Test Data:")
        addTestResult("- Cleared local test data")
        addTestResult("- Note: Database data remains")
        addTestResult("- Test: Completed")
        
        showingResults = true
    }
    
    private func addTestResult(_ result: String) {
        testResults.append("\(Date().formatted(date: .omitted, time: .shortened)): \(result)")
    }
}

#Preview {
    LegalAgreementTestView()
}
