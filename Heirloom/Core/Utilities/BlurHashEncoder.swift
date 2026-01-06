import UIKit

/// Native BlurHash encoder/decoder implementation
/// No external dependencies - self-contained utility
/// Based on the BlurHash algorithm: https://github.com/woltapp/blurhash
struct BlurHashEncoder {

    // MARK: - Encoding

    /// Generate a blurhash string from an image
    /// - Parameters:
    ///   - image: Source image to encode
    ///   - componentsX: Number of horizontal components (4-9 recommended)
    ///   - componentsY: Number of vertical components (3-9 recommended)
    /// - Returns: BlurHash string, or nil if encoding fails
    static func encode(_ image: UIImage, componentsX: Int = 4, componentsY: Int = 3) -> String? {
        guard componentsX >= 1, componentsX <= 9,
              componentsY >= 1, componentsY <= 9,
              let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4

        guard let data = cgImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data) else {
            return nil
        }

        var factors: [(Float, Float, Float)] = []

        for y in 0..<componentsY {
            for x in 0..<componentsX {
                let normalisation: Float = (x == 0 && y == 0) ? 1.0 : 2.0
                let factor = multiplyBasisFunction(
                    pixels: pixels,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    basisX: x,
                    basisY: y,
                    normalisation: normalisation
                )
                factors.append(factor)
            }
        }

        guard let dc = factors.first else { return nil }
        let ac = Array(factors.dropFirst())

        var hash = ""

        let sizeFlag = (componentsX - 1) + (componentsY - 1) * 9
        hash += encodeBase83(Int(sizeFlag), length: 1)

        let maximumValue: Float
        if !ac.isEmpty {
            let actualMaximumValue = ac.map { max(abs($0.0), abs($0.1), abs($0.2)) }.max() ?? 0
            let quantisedMaximumValue = Int(max(0, min(82, floor(actualMaximumValue * 166 - 0.5))))
            maximumValue = Float(quantisedMaximumValue + 1) / 166
            hash += encodeBase83(quantisedMaximumValue, length: 1)
        } else {
            maximumValue = 1
            hash += encodeBase83(0, length: 1)
        }

        hash += encodeBase83(encodeDC(dc), length: 4)

        for factor in ac {
            hash += encodeBase83(encodeAC(factor, maximumValue: maximumValue), length: 2)
        }

        return hash
    }

    // MARK: - Decoding

    /// Decode a blurhash string into a UIImage
    /// - Parameters:
    ///   - blurHash: The blurhash string
    ///   - size: Target size for the decoded image
    /// - Returns: Decoded image, or nil if decoding fails
    static func decode(_ blurHash: String, size: CGSize) -> UIImage? {
        guard blurHash.count >= 6 else { return nil }

        let sizeFlag = decodeBase83(String(blurHash.prefix(1))) ?? 0
        let componentsX = (sizeFlag % 9) + 1
        let componentsY = (sizeFlag / 9) + 1

        guard blurHash.count == 4 + 2 * componentsX * componentsY else { return nil }

        let maxAC = decodeBase83(String(blurHash.dropFirst().prefix(1))) ?? 0
        let maxACValue = Float(maxAC + 1) / 166.0

        var colors: [(Float, Float, Float)] = []

        // Decode DC
        let dcValue = decodeBase83(String(blurHash.dropFirst(2).prefix(4))) ?? 0
        colors.append(decodeDC(dcValue))

        // Decode AC
        var index = 6
        for _ in 0..<(componentsX * componentsY - 1) {
            let acValue = decodeBase83(String(blurHash.dropFirst(index).prefix(2))) ?? 0
            colors.append(decodeAC(acValue, maximumValue: maxACValue))
            index += 2
        }

        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                var r: Float = 0, g: Float = 0, b: Float = 0

                for j in 0..<componentsY {
                    for i in 0..<componentsX {
                        let basis = cos(Float.pi * Float(x) * Float(i) / Float(width)) *
                                   cos(Float.pi * Float(y) * Float(j) / Float(height))
                        let color = colors[i + j * componentsX]
                        r += color.0 * basis
                        g += color.1 * basis
                        b += color.2 * basis
                    }
                }

                let pixelIndex = (y * bytesPerRow) + (x * 4)
                pixels[pixelIndex] = UInt8(linearToSRGB(r))
                pixels[pixelIndex + 1] = UInt8(linearToSRGB(g))
                pixels[pixelIndex + 2] = UInt8(linearToSRGB(b))
                pixels[pixelIndex + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Private Helpers

    private static func multiplyBasisFunction(
        pixels: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        basisX: Int,
        basisY: Int,
        normalisation: Float
    ) -> (Float, Float, Float) {
        var r: Float = 0, g: Float = 0, b: Float = 0

        for y in 0..<height {
            for x in 0..<width {
                let basis = normalisation *
                    cos(Float.pi * Float(basisX) * Float(x) / Float(width)) *
                    cos(Float.pi * Float(basisY) * Float(y) / Float(height))

                let pixelIndex = y * bytesPerRow + x * 4
                r += basis * sRGBToLinear(Float(pixels[pixelIndex]))
                g += basis * sRGBToLinear(Float(pixels[pixelIndex + 1]))
                b += basis * sRGBToLinear(Float(pixels[pixelIndex + 2]))
            }
        }

        let scale = 1.0 / Float(width * height)
        return (r * scale, g * scale, b * scale)
    }

    private static func encodeDC(_ dc: (Float, Float, Float)) -> Int {
        let r = Int(linearToSRGB(dc.0))
        let g = Int(linearToSRGB(dc.1))
        let b = Int(linearToSRGB(dc.2))
        return (r << 16) + (g << 8) + b
    }

    private static func decodeDC(_ value: Int) -> (Float, Float, Float) {
        let r = value >> 16
        let g = (value >> 8) & 255
        let b = value & 255
        return (sRGBToLinear(Float(r)), sRGBToLinear(Float(g)), sRGBToLinear(Float(b)))
    }

    private static func encodeAC(_ ac: (Float, Float, Float), maximumValue: Float) -> Int {
        let quantR = Int(max(0, min(18, floor(signPow(ac.0 / maximumValue, 0.5) * 9 + 9.5))))
        let quantG = Int(max(0, min(18, floor(signPow(ac.1 / maximumValue, 0.5) * 9 + 9.5))))
        let quantB = Int(max(0, min(18, floor(signPow(ac.2 / maximumValue, 0.5) * 9 + 9.5))))
        return quantR * 19 * 19 + quantG * 19 + quantB
    }

    private static func decodeAC(_ value: Int, maximumValue: Float) -> (Float, Float, Float) {
        let quantR = value / (19 * 19)
        let quantG = (value / 19) % 19
        let quantB = value % 19

        return (
            signPow((Float(quantR) - 9) / 9, 2) * maximumValue,
            signPow((Float(quantG) - 9) / 9, 2) * maximumValue,
            signPow((Float(quantB) - 9) / 9, 2) * maximumValue
        )
    }

    private static func signPow(_ value: Float, _ exp: Float) -> Float {
        return copysign(pow(abs(value), exp), value)
    }

    private static func sRGBToLinear(_ value: Float) -> Float {
        let v = value / 255
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ value: Float) -> Float {
        let v = max(0, min(1, value))
        let sRGB = v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
        return max(0, min(255, sRGB * 255))
    }

    // MARK: - Base83 Encoding/Decoding

    private static let base83Characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~")

    private static func encodeBase83(_ value: Int, length: Int) -> String {
        var result = ""
        var value = value
        for _ in 0..<length {
            result = String(base83Characters[value % 83]) + result
            value = value / 83
        }
        return result
    }

    private static func decodeBase83(_ string: String) -> Int? {
        var value = 0
        for char in string {
            guard let index = base83Characters.firstIndex(of: char) else {
                return nil
            }
            value = value * 83 + index
        }
        return value
    }
}
