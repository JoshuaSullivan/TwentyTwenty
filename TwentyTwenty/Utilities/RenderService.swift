import UIKit
import CoreImage
import Metal

/// Actor-based service for thread-safe Core Image rendering using a reusable Metal-backed context
actor RenderService {
    // MARK: - Singleton

    static let shared = RenderService()

    // MARK: - Properties

    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    // MARK: - Initialization

    private init() {
        // Try to create Metal-backed context for best performance
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            let options: [CIContextOption: Any] = [
                .workingColorSpace: NSNull(),
                .cacheIntermediates: false
            ]
            ciContext = CIContext(mtlDevice: metalDevice, options: options)
        } else {
            // Fallback to CPU context if Metal is unavailable
            let options: [CIContextOption: Any] = [
                .workingColorSpace: NSNull()
            ]
            ciContext = CIContext(options: options)
        }
    }

    // MARK: - Public Methods

    /// Renders a CIImage to a CGImage using the shared Metal-backed context
    /// - Parameters:
    ///   - image: The CIImage to render
    ///   - rect: The rect to render from (defaults to image extent)
    /// - Returns: Rendered CGImage, or nil if rendering fails
    func render(image: CIImage, from rect: CGRect? = nil) -> CGImage? {
        let renderRect = rect ?? image.extent
        return ciContext.createCGImage(image, from: renderRect, format: .RGBA8, colorSpace: colorSpace)
    }

    /// Renders a CIImage to a UIImage using the shared Metal-backed context
    /// - Parameters:
    ///   - image: The CIImage to render
    ///   - rect: The rect to render from (defaults to image extent)
    /// - Returns: Rendered UIImage, or nil if rendering fails
    func renderToUIImage(image: CIImage, from rect: CGRect? = nil) -> UIImage? {
        guard let cgImage = render(image: image, from: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
