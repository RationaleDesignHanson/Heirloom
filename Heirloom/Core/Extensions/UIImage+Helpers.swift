import UIKit

extension UIImage {
    /// Create a placeholder image with a color and optional SF Symbol
    static func placeholder(
        color: UIColor = .systemGray5,
        size: CGSize = CGSize(width: 200, height: 200),
        symbolName: String? = nil
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Fill background
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add symbol if provided
            if let symbolName = symbolName,
               let symbol = UIImage(systemName: symbolName) {
                let config = UIImage.SymbolConfiguration(pointSize: size.width * 0.3, weight: .light)
                let configured = symbol.withConfiguration(config)

                let tintColor = UIColor.systemGray3
                tintColor.setFill()

                let symbolSize = configured.size
                let x = (size.width - symbolSize.width) / 2
                let y = (size.height - symbolSize.height) / 2

                configured.draw(at: CGPoint(x: x, y: y))
            }
        }
    }

    /// Resize image to max dimension while maintaining aspect ratio
    func resized(maxDimension: CGFloat) -> UIImage? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)

        if scale >= 1.0 {
            return self  // Already smaller than max
        }

        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
