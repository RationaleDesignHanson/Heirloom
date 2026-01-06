import Foundation
import UIKit

/// Memory cache for recipe images
/// Reduces disk I/O when scrolling through recipe lists
final class ImageCache: ImageCacheProtocol {
    private let cache = NSCache<NSURL, UIImage>()
    private let maxMemoryCacheSize: Int = 50_000_000  // 50MB
    private var memoryWarningObserver: NSObjectProtocol?

    init() {
        cache.totalCostLimit = maxMemoryCacheSize

        // Clear cache on memory warning (properly stored to avoid retain cycle)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Protocol Conformance (String-based keys)

    /// Cache an image with a string key (for protocol conformance)
    func cache(_ image: UIImage, for key: String) {
        guard let url = URL(string: key) else { return }
        setImage(image, for: url)
    }

    /// Retrieve an image with a string key (for protocol conformance)
    func retrieve(for key: String) -> UIImage? {
        guard let url = URL(string: key) else { return nil }
        return image(for: url)
    }

    /// Clear all cached images (for protocol conformance)
    func clear() {
        clearCache()
    }

    // MARK: - Cache Operations (URL-based keys)

    func image(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = estimateImageMemorySize(image)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    func clearCache() {
        cache.removeAllObjects()
        Log.info("Cleared image cache due to memory warning", category: .storage)
    }

    // MARK: - Helpers

    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerRow = cgImage.bytesPerRow
        let height = cgImage.height
        return bytesPerRow * height
    }
}
