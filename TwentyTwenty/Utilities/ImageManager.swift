import UIKit
import SwiftUI

/// Manages loading and caching of bundled sample images
struct ImageManager {
    // MARK: - Public Methods

    /// Loads a bundled image from the asset catalog
    /// - Parameter bundledImage: The bundled image to load
    /// - Returns: UIImage if found, nil otherwise
    static func loadImage(_ bundledImage: BundledImage) -> UIImage? {
        UIImage(named: bundledImage.assetName)
    }

    /// Loads a bundled image as a SwiftUI Image
    /// - Parameter bundledImage: The bundled image to load
    /// - Returns: SwiftUI Image
    static func loadSwiftUIImage(_ bundledImage: BundledImage) -> Image {
        Image(bundledImage.assetName)
    }

    /// Checks if a bundled image asset exists
    /// - Parameter bundledImage: The bundled image to check
    /// - Returns: true if the asset exists, false otherwise
    static func imageExists(_ bundledImage: BundledImage) -> Bool {
        loadImage(bundledImage) != nil
    }

    /// Returns all available bundled images that actually exist in the asset catalog
    /// - Returns: Array of bundled images with valid assets
    static func availableImages() -> [BundledImage] {
        BundledImageRegistry.allImages.filter { imageExists($0) }
    }
}

// MARK: - Image Extension

extension UIImage {
    /// Resizes the image to fit within the specified maximum dimension while maintaining aspect ratio
    /// - Parameter maxDimension: Maximum width or height
    /// - Returns: Resized image
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let aspectRatio = size.width / size.height

        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    /// Returns the image's size in bytes (approximate)
    var sizeInBytes: Int {
        guard let cgImage = self.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
