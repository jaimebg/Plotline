import SwiftUI
import UIKit

/// Thread-safe image cache using NSCache
actor ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private var loadingTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    // MARK: - Public Methods

    /// Get cached image for URL
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    /// Store image in cache
    func setImage(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }

    /// Load image from URL with caching
    func loadImage(from url: URL) async -> UIImage? {
        // Check cache first
        if let cached = image(for: url) {
            return cached
        }

        // Check if already loading
        let key = url.absoluteString
        if let existingTask = loadingTasks[key] {
            return await existingTask.value
        }

        // Create new loading task
        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                setImage(image, for: url)
                return image
            } catch {
                #if DEBUG
                print("Failed to load image: \(error)")
                #endif
                return nil
            }
        }

        loadingTasks[key] = task
        let result = await task.value
        loadingTasks[key] = nil

        return result
    }

    /// Clear all cached images
    func clearAll() {
        cache.removeAllObjects()
        loadingTasks.removeAll()
    }

    /// Remove specific image from cache
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }
}

// MARK: - Cached Async Image View

/// A wrapper around AsyncImage that uses our cache
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url, !isLoading else { return }

        isLoading = true
        image = await ImageCache.shared.loadImage(from: url)
        isLoading = false
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(url: url) { image in
            image.resizable()
        } placeholder: {
            ProgressView()
        }
    }
}
