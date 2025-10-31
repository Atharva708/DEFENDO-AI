import Combine
import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var phoneNumber: String = ""
    @Published var isSendingOTP: Bool = false
    @Published var isVerifying: Bool = false
    @Published var showOTPOverlay: Bool = false
    @Published var otpCode: String = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isLoggedIn: Bool = false

    private let service = SupabaseService.shared

    init() {
        self.isLoggedIn = service.currentSessionUserId() != nil
    }

    func startOTP() async {
        errorMessage = nil
        successMessage = nil
        let phone = normalized(phoneNumber)
        guard !phone.isEmpty else {
            errorMessage = "Enter a valid phone number"
            return
        }
        isSendingOTP = true
        do {
            try await service.startOTP(for: phone)
            showOTPOverlay = true
            successMessage = "OTP sent to \(phone)"
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isSendingOTP = false
    }

    func verifyOTP() async {
        errorMessage = nil
        successMessage = nil
        let phone = normalized(phoneNumber)
        guard !phone.isEmpty, !otpCode.isEmpty else {
            errorMessage = "Enter the OTP code"
            return
        }
        isVerifying = true
        do {
            if let userId = try await service.verifyOTP(phoneNumber: phone, code: otpCode) {
                service.storeSession(userId: userId)
                isLoggedIn = true
                showOTPOverlay = false
                successMessage = "Logged in successfully"
            } else {
                errorMessage = "Verification failed"
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isVerifying = false
    }

    func signOut() {
        service.signOut()
        isLoggedIn = false
    }

    private func normalized(_ input: String) -> String {
        // Remove all non-digit characters except +
        let cleaned = input.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        // If it doesn't start with +, assume it's an Indian number and add +91
        if !cleaned.hasPrefix("+") {
            let digits = cleaned.filter { $0.isNumber }
            if digits.count == 10 {
                return "+91" + digits
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Async Image Loader with Cache

actor ImageCache {
    static let shared = ImageCache()
    private var cache: [URL: UIImage] = [:]

    func image(for url: URL) -> UIImage? { cache[url] }
    func insert(_ image: UIImage, for url: URL) { cache[url] = image }
}

struct AsyncCachedImage: View {
    let urlString: String?
    let placeholder: () -> AnyView

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage { Image(uiImage: uiImage).resizable().scaledToFill() }
            else { placeholder() }
        }
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        guard let urlString, let url = URL(string: urlString) else { return }
        if let cached = await ImageCache.shared.image(for: url) {
            await MainActor.run { self.uiImage = cached }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await ImageCache.shared.insert(image, for: url)
                await MainActor.run { self.uiImage = image }
            }
        } catch {
            // Ignore or log
        }
    }
}
