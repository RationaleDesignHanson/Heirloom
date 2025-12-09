import Foundation
import UIKit

/// Memory cache for recipe images
/// Reduces disk I/O when scrolling through recipe lists
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private let maxMemoryCacheSize: Int = 50_000_000  // 50MB
    private var memoryWarningObserver: NSObjectProtocol?

    private init() {
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

    // MARK: - Cache Operations

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
        print("🧹 Cleared image cache due to memory warning")
    }

    // MARK: - Helpers

    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerRow = cgImage.bytesPerRow
        let height = cgImage.height
        return bytesPerRow * height
    }
}
