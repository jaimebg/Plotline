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
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: Self.cost(of: image))
    }

    /// Decoded size in bytes: four bytes per pixel at the image's scale.
    ///
    /// What the cache actually holds is the decoded bitmap, so that is what
    /// `totalCostLimit` should count — and re-encoding every image as a
    /// full-quality JPEG just to measure it cost more than the load itself.
    static func cost(of image: UIImage) -> Int {
        cost(width: image.size.width, height: image.size.height, scale: image.scale)
    }

    static func cost(width: CGFloat, height: CGFloat, scale: CGFloat) -> Int {
        let pixels = (width * scale) * (height * scale)
        guard pixels.isFinite, pixels > 0 else { return 0 }
        return Int(pixels) * 4
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

/// A wrapper around AsyncImage that uses our cache.
///
/// Keyed on `url`: when a reused cell is handed a different URL, the previous
/// image is dropped and the new one loaded, rather than the old poster staying
/// on screen. A failed load shows `failure` instead of leaving the
/// placeholder's spinner running forever, and is retried the next time the
/// view appears.
struct CachedAsyncImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    @State private var loaded: LoadedImage?
    @State private var failedURL: URL?

    private struct LoadedImage {
        let url: URL
        let image: UIImage
    }

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        Group {
            if let loaded, loaded.url == url {
                content(Image(uiImage: loaded.image))
            } else if let failedURL, failedURL == url {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            loaded = nil
            failedURL = nil
            return
        }
        if let loaded, loaded.url == url { return }

        loaded = nil
        failedURL = nil

        let image = await ImageCache.shared.loadImage(from: url)

        // Cancelled means the view went away or its URL changed; whichever
        // task replaces this one owns the state now.
        guard !Task.isCancelled else { return }

        if let image {
            loaded = LoadedImage(url: url, image: image)
        } else {
            failedURL = url
        }
    }
}

// MARK: - Failure View

/// Shown in place of a placeholder whose load failed. Laid over the caller's
/// own placeholder so it takes exactly the placeholder's size and shape, and
/// hides the spinner that placeholder would otherwise keep running.
struct ImageLoadFailureOverlay<Placeholder: View>: View {
    let placeholder: Placeholder

    var body: some View {
        placeholder
            .overlay {
                Rectangle()
                    .fill(Color.plotlineCard)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Image unavailable")
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Failure == ImageLoadFailureOverlay<Placeholder> {
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(url: url, content: content, placeholder: placeholder) {
            ImageLoadFailureOverlay(placeholder: placeholder())
        }
    }
}

extension CachedAsyncImage
where Placeholder == ProgressView<EmptyView, EmptyView>, Failure == ImageLoadFailureOverlay<Placeholder> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}

extension CachedAsyncImage
where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView>, Failure == ImageLoadFailureOverlay<Placeholder> {
    init(url: URL?) {
        self.init(url: url) { image in
            image.resizable()
        } placeholder: {
            ProgressView()
        }
    }
}
