//
//  OptimizedImageService.swift
//  DEFENDO-AI
//
//  Optimized image loading and caching service
//

import Foundation
import SwiftUI
import UIKit
import Combine // ✅ Required for ObservableObject and @Published

// MARK: - Image Cache Manager
actor ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private var memoryCache: [String: UIImage] = [:]
    private var diskCache: [String: Data] = [:]
    private let maxMemoryCacheSize = 50 // Maximum number of images in memory
    private let maxDiskCacheSize = 200 // Maximum number of images on disk
    private let cacheDirectory: URL
    
    init() {
        // Create cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load existing disk cache
        loadDiskCache()
    }
    
    // MARK: - Public Methods
    
    func getImage(for url: String) -> UIImage? {
        // Check memory cache first
        if let image = memoryCache[url] {
            return image
        }
        
        // Check disk cache
        if let data = diskCache[url], let image = UIImage(data: data) {
            // Move to memory cache
            memoryCache[url] = image
            return image
        }
        
        return nil
    }
    
    func setImage(_ image: UIImage, for url: String) {
        // Add to memory cache
        memoryCache[url] = image
        
        // Add to disk cache
        if let data = image.jpegData(compressionQuality: 0.8) {
            diskCache[url] = data
            saveToDisk(url: url, data: data)
        }
        
        // Manage cache sizes
        manageMemoryCache()
        manageDiskCache()
    }
    
    func clearCache() {
        memoryCache.removeAll()
        diskCache.removeAll()
        
        // Clear disk files
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Private Methods
    
    private func loadDiskCache() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let url = file.lastPathComponent
                if let data = try? Data(contentsOf: file) {
                    diskCache[url] = data
                }
            }
        } catch {
            print("[ImageCache] Failed to load disk cache: \(error)")
        }
    }
    
    private func saveToDisk(url: String, data: Data) {
        let safeName = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDirectory.appendingPathComponent(safeName)
        try? data.write(to: fileURL)
    }
    
    private func manageMemoryCache() {
        if memoryCache.count > maxMemoryCacheSize {
            // Remove oldest entries (simple LRU)
            let keysToRemove = Array(memoryCache.keys.prefix(memoryCache.count - maxMemoryCacheSize))
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
    }
    
    private func manageDiskCache() {
        if diskCache.count > maxDiskCacheSize {
            // Remove oldest entries
            let keysToRemove = Array(diskCache.keys.prefix(diskCache.count - maxDiskCacheSize))
            for key in keysToRemove {
                diskCache.removeValue(forKey: key)
                let fileURL = cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

// MARK: - Optimized Image Loader
struct OptimizedAsyncImage: View {
    let urlString: String?
    let placeholder: () -> AnyView
    let content: (Image) -> AnyView
    
    @State private var uiImage: UIImage?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?
    
    init(
        urlString: String?,
        @ViewBuilder placeholder: @escaping () -> AnyView = { AnyView(ProgressView()) },
        @ViewBuilder content: @escaping (Image) -> AnyView = { AnyView($0.resizable().scaledToFill()) }
    ) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.content = content
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
    
    private func loadImage() async {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        
        // Check cache first
        if let cachedImage = await ImageCacheManager.shared.getImage(for: urlString) {
            await MainActor.run {
                self.uiImage = cachedImage
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        loadTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let image = UIImage(data: data) {
                    // Cache the image
                    await ImageCacheManager.shared.setImage(image, for: urlString)
                    
                    await MainActor.run {
                        self.uiImage = image
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("[OptimizedAsyncImage] Failed to load image: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Image Loading Service
final class ImageLoadingService: ObservableObject {
    static let shared = ImageLoadingService()
    
    @Published var isLoading = false
    @Published var loadedImages: [String: UIImage] = [:]
    
    private init() {}
    
    func loadImage(from urlString: String) async -> UIImage? {
        // Check if already loaded
        if let image = loadedImages[urlString] {
            return image
        }
        
        // Check cache
        if let cachedImage = await ImageCacheManager.shared.getImage(for: urlString) {
            await MainActor.run {
                self.loadedImages[urlString] = cachedImage
            }
            return cachedImage
        }
        
        // Load from network
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            await MainActor.run { self.isLoading = true }
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run { self.isLoading = false }
            
            if let image = UIImage(data: data) {
                // Cache the image
                await ImageCacheManager.shared.setImage(image, for: urlString)
                
                await MainActor.run {
                    self.loadedImages[urlString] = image
                }
                return image
            }
        } catch {
            await MainActor.run { self.isLoading = false }
            print("[ImageLoadingService] Failed to load image: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    func preloadImages(from urlStrings: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for urlString in urlStrings {
                group.addTask {
                    _ = await self.loadImage(from: urlString)
                }
            }
        }
    }
    
    func clearCache() async {
        await ImageCacheManager.shared.clearCache()
        await MainActor.run {
            self.loadedImages.removeAll()
        }
    }
}

// MARK: - Convenience Extensions
extension OptimizedAsyncImage {
    init(urlString: String?) {
        self.init(
            urlString: urlString,
            placeholder: { AnyView(ProgressView()) },
            content: { AnyView($0.resizable().scaledToFill()) }
        )
    }
    
    init(urlString: String?, @ViewBuilder placeholder: @escaping () -> AnyView) {
        self.init(
            urlString: urlString,
            placeholder: placeholder,
            content: { AnyView($0.resizable().scaledToFill()) }
        )
    }
}
