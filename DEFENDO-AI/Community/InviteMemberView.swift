//
//  InviteMemberView.swift
//  DEFENDO-AI
//
//  Invite member modal with phone number search
//

import SwiftUI

struct InviteMemberView: View {
    let communityId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var statusMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Invite Member")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Phone Number")
                        .font(.headline)
                    
                    TextField("Enter phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                
                if let statusMessage = statusMessage {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(statusMessage.contains("✅") ? .green : .red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button {
                    Task { await inviteMember() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Invite")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(phoneNumber.isEmpty || isLoading)
            }
            .padding()
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func inviteMember() async {
        isLoading = true
        statusMessage = nil
        
        do {
            try await CommunityService.shared.inviteMemberByPhone(phoneNumber: phoneNumber, communityId: communityId)
            statusMessage = "✅ Member added successfully"
            phoneNumber = ""
            
            // Auto-dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            statusMessage = "❌ " + error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    InviteMemberView(communityId: UUID())
}
