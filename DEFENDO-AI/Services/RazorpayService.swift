import Foundation
import UIKit
import Combine

#if canImport(Razorpay)
import Razorpay
#endif

final class RazorpayService: NSObject, ObservableObject {
    static let shared = RazorpayService()

    // Your test key provided
    private let keyId: String = "rzp_test_RDymBSsTitkLdn"

    @Published var isProcessing: Bool = false

    private override init() {
        super.init()
    }

    struct PaymentRequest: Sendable {
        let amount: Double              // Amount in base units (e.g. 100.00)
        let currencyCode: String        // e.g. "INR"
        let description: String         // Description shown in checkout
        let orderId: String?            // Optional: set server-created order_id for best practice
        let metadata: [String: String]? // Additional key-value pairs
        let customerEmail: String?      // Optional: prefill email
        let customerPhone: String?      // Optional: prefill phone
    }

    struct PaymentResult: Sendable {
        let paymentId: String
        let status: String
    }

    enum PaymentError: LocalizedError {
        case failed(String)
        case cancelled
        case sdkUnavailable

        var errorDescription: String? {
            switch self {
            case .failed(let msg): return msg
            case .cancelled: return "Payment was cancelled"
            case .sdkUnavailable: return "Razorpay SDK is not available in this build"
            }
        }
    }

    // MARK: - Public API (async/await)
    func pay(_ request: PaymentRequest) async throws -> PaymentResult {
        #if canImport(Razorpay)
        guard let topVC = RazorpayService.topMostViewController() else {
            throw PaymentError.failed("Unable to find a screen to present Checkout")
        }

        isProcessing = true
        defer { isProcessing = false }

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = CheckoutDelegate { result in
                continuation.resume(returning: result)
            } onFailure: { err in
                continuation.resume(throwing: err)
            }

            let razorpay = RazorpayCheckout.initWithKey(keyId, andDelegate: delegate)

            var options: [String: Any] = [
                "key": keyId,
                "amount": Int(request.amount * 100.0), // Razorpay expects paise
                "currency": request.currencyCode,
                "description": request.description,
                "theme": ["color": "#3B82F6"]
            ]
            if let orderId = request.orderId { options["order_id"] = orderId }
            if let meta = request.metadata { options["notes"] = meta }
            var prefill: [String: String] = [:]
            if let email = request.customerEmail { prefill["email"] = email }
            if let phone = request.customerPhone { prefill["contact"] = phone }
            if !prefill.isEmpty { options["prefill"] = prefill }

            // Retain delegate during presentation lifecycle
            CheckoutDelegateRegistry.shared.register(delegate)

            DispatchQueue.main.async {
                razorpay.open(options, displayController: topVC)
            }
        }
        #else
        throw PaymentError.sdkUnavailable
        #endif
    }
}

// MARK: - Internal Helpers
extension RazorpayService {
    private static func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController { return topMostViewController(base: selected) }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
}

#if canImport(Razorpay)
// MARK: - Delegate wrapper bridging to async
private final class CheckoutDelegate: NSObject, RazorpayPaymentCompletionProtocol {
    private let onSuccess: (RazorpayService.PaymentResult) -> Void
    private let onFailure: (Error) -> Void

    init(onSuccess: @escaping (RazorpayService.PaymentResult) -> Void,
         onFailure: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    func onPaymentError(_ code: Int32, description str: String) {
        CheckoutDelegateRegistry.shared.unregister(self)
        if code == 2 { // Payment cancelled
            onFailure(RazorpayService.PaymentError.cancelled)
        } else {
            onFailure(RazorpayService.PaymentError.failed(str))
        }
    }

    func onPaymentSuccess(_ payment_id: String) {
        CheckoutDelegateRegistry.shared.unregister(self)
        onSuccess(.init(paymentId: payment_id, status: "paid"))
    }
}

// Keep strong references to delegates while checkout UI is visible
private final class CheckoutDelegateRegistry {
    static let shared = CheckoutDelegateRegistry()
    private var delegates: [AnyObject] = [] // strong references to retain during checkout
    private init() {}
    func register(_ delegate: AnyObject) { delegates.append(delegate) }
    func unregister(_ delegate: AnyObject) {
        delegates.removeAll { $0 === delegate }
    }
}
#endif


