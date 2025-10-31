import SwiftUI

struct MobileAuthView: View {
    @StateObject private var vm = AuthViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Text("Welcome to DEFENDO-AI").font(.largeTitle).bold()
                Text("Sign in or sign up with your mobile number")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Mobile Number").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("+1 555 123 4567", text: $vm.phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focused)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                }

                Button(action: { Task { await vm.startOTP() } }) {
                    if vm.isSendingOTP { ProgressView() } else { Text("Continue").bold() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isSendingOTP || vm.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                if let success = vm.successMessage {
                    Text(success).foregroundStyle(.green).font(.footnote)
                }

                Spacer()
            }
            .padding()

            if vm.showOTPOverlay { OTPOverlayView(isPresented: $vm.showOTPOverlay, code: $vm.otpCode, isVerifying: vm.isVerifying, onVerify: { Task { await vm.verifyOTP() } }) }
        }
        .animation(.smooth, value: vm.showOTPOverlay)
        .onTapGesture { focused = false }
    }
}

struct OTPOverlayView: View {
    @Binding var isPresented: Bool
    @Binding var code: String
    var isVerifying: Bool
    var onVerify: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.35 : 0)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top, 8)
                Text("Enter OTP").font(.title2).bold()
                Text("We sent a code to your phone").foregroundStyle(.secondary)

                HStack {
                    TextField("123456", text: $code)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }

                Button(action: onVerify) {
                    if isVerifying { ProgressView() } else { Text("Verify & Continue").bold() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isVerifying || code.isEmpty)

                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
            }
            .padding()
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .offset(y: appear ? 0 : 40)
            .opacity(appear ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appear = true } }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.02)), removal: .opacity))
    }
}

#Preview {
    MobileAuthView()
}
