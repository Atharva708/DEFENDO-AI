import Foundation
import SwiftUI
import Combine

// MARK: - Performance Service
/// Centralized service for performance optimizations, caching, and monitoring
@MainActor
class PerformanceService: ObservableObject {
    static let shared = PerformanceService()
    
    // MARK: - Performance Metrics
    @Published var networkLatency: TimeInterval = 0
    @Published var cacheHitRate: Double = 0
    @Published var memoryUsage: UInt64 = 0
    @Published var isOptimizedMode = true
    
    // MARK: - Private Properties
    private var networkLatencyHistory: [TimeInterval] = []
    private var cacheHits = 0
    private var cacheMisses = 0
    private var performanceTimer: Timer?
    
    private init() {
        startPerformanceMonitoring()
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        // Update memory usage
        memoryUsage = getCurrentMemoryUsage()
        
        // Update cache hit rate
        let totalRequests = cacheHits + cacheMisses
        cacheHitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
        
        // Clean up old latency data
        if networkLatencyHistory.count > 100 {
            networkLatencyHistory.removeFirst(20)
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    // MARK: - Network Performance
    
    func recordNetworkLatency(_ latency: TimeInterval) {
        networkLatencyHistory.append(latency)
        networkLatency = networkLatencyHistory.reduce(0, +) / Double(networkLatencyHistory.count)
    }
    
    func recordCacheHit() {
        cacheHits += 1
    }
    
    func recordCacheMiss() {
        cacheMisses += 1
    }
    
    // MARK: - Optimization Methods
    
    func enableOptimizedMode() {
        isOptimizedMode = true
        // Enable various optimizations
        enableImageCaching()
        enableDataCompression()
        enableBackgroundProcessing()
    }
    
    func disableOptimizedMode() {
        isOptimizedMode = false
        // Disable optimizations for debugging
    }
    
    private func enableImageCaching() {
        // Configure image caching
        URLCache.shared.memoryCapacity = 50 * 1024 * 1024 // 50MB
        URLCache.shared.diskCapacity = 200 * 1024 * 1024 // 200MB
    }
    
    private func enableDataCompression() {
        // Enable data compression for network requests
        // This would be implemented in the network layer
    }
    
    private func enableBackgroundProcessing() {
        // Configure background processing for data fetching
        // This would be implemented in the data services
    }
    
    // MARK: - Memory Management
    
    func clearCaches() {
        URLCache.shared.removeAllCachedResponses()
        // Clear custom caches
        clearCustomCaches()
    }
    
    private func clearCustomCaches() {
        // Clear any custom caches implemented in the app
        // This would be called by individual services
    }
    
    // MARK: - Performance Recommendations
    
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if networkLatency > 2.0 {
            recommendations.append("Network latency is high. Consider using cached data.")
        }
        
        if cacheHitRate < 0.5 {
            recommendations.append("Cache hit rate is low. Consider improving caching strategy.")
        }
        
        if memoryUsage > 100 * 1024 * 1024 { // 100MB
            recommendations.append("Memory usage is high. Consider clearing caches.")
        }
        
        return recommendations
    }
}

// MARK: - Optimized Image Cache
class OptimizedImageCache {
    static let shared = OptimizedImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024 // 50MB
    
    private init() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 100
    }
    
    func image(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func setImage(_ image: UIImage, for url: String) {
        let cost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Optimized Data Cache
class OptimizedDataCache {
    static let shared = OptimizedDataCache()
    
    private let cache = NSCache<NSString, NSData>()
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    
    private init() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 200
    }
    
    func data(for key: String) -> Data? {
        return cache.object(forKey: key as NSString) as Data?
    }
    
    func setData(_ data: Data, for key: String) {
        cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Network Performance Monitor
class NetworkPerformanceMonitor {
    static let shared = NetworkPerformanceMonitor()
    
    private var requestStartTimes: [String: Date] = [:]
    
    func startRequest(for url: String) {
        requestStartTimes[url] = Date()
    }
    
    func endRequest(for url: String) {
        guard let startTime = requestStartTimes[url] else { return }
        let latency = Date().timeIntervalSince(startTime)
        PerformanceService.shared.recordNetworkLatency(latency)
        requestStartTimes.removeValue(forKey: url)
    }
}

// MARK: - Performance Optimized View Modifier
struct PerformanceOptimized: ViewModifier {
    @StateObject private var performanceService = PerformanceService.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if performanceService.isOptimizedMode {
                    // Apply performance optimizations
                    content
                        .drawingGroup() // Rasterize complex views
                        .animation(.easeInOut(duration: 0.2)) // Smooth animations
                } else {
                    content
                }
            }
    }
}

extension View {
    func performanceOptimized() -> some View {
        modifier(PerformanceOptimized())
    }
}

// MARK: - Lazy Loading Helper
struct LazyLoadingView<Content: View>: View {
    let content: () -> Content
    @State private var isLoaded = false
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if isLoaded {
                content()
            } else {
                ProgressView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isLoaded = true
                        }
                    }
            }
        }
    }
}

// MARK: - Debounced Text Field
struct DebouncedTextField: View {
    let title: String
    @Binding var text: String
    let onTextChange: (String) -> Void
    
    @State private var debounceTask: Task<Void, Never>?
    
    init(_ title: String, text: Binding<String>, onTextChange: @escaping (String) -> Void) {
        self.title = title
        self._text = text
        self.onTextChange = onTextChange
    }
    
    var body: some View {
        TextField(title, text: $text)
            .onChange(of: text) { newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                    if !Task.isCancelled {
                        onTextChange(newValue)
                    }
                }
            }
    }
}
