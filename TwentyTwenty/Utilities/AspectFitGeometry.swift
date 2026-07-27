import CoreGraphics

/// Maps between view coordinates and normalized image coordinates for an image
/// displayed with `scaledToFit` (aspect-fit) inside a container.
///
/// When an image is aspect-fit into a view, it is letterboxed or pillarboxed so that
/// the whole image is visible. Interactive overlays need to convert taps in view space
/// into normalized image space, and to convert stored normalized points back into view
/// space in order to draw markers. This type owns both directions of that conversion.
///
/// All normalized coordinates use a **top-left origin** to match SwiftUI and UIKit.
/// Vision's bottom-left origin conversion is deliberately *not* handled here — callers
/// perform that flip at the boundary where they hand values to the Vision framework.
struct AspectFitGeometry {
    /// The rectangle, in view coordinates, actually occupied by the image.
    let imageFrame: CGRect

    /// Creates a geometry mapping for an image aspect-fit into a container.
    /// - Parameters:
    ///   - imageSize: The intrinsic size of the image.
    ///   - viewSize: The size of the container the image is fit into.
    init(imageSize: CGSize, viewSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            imageFrame = CGRect(origin: .zero, size: viewSize)
            return
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            // Image is proportionally wider than the view — fit to width, letterbox vertically.
            let displayHeight = viewSize.width / imageAspect
            let yOffset = (viewSize.height - displayHeight) / 2
            imageFrame = CGRect(x: 0, y: yOffset, width: viewSize.width, height: displayHeight)
        } else {
            // Image is proportionally taller than the view — fit to height, pillarbox horizontally.
            let displayWidth = viewSize.height * imageAspect
            let xOffset = (viewSize.width - displayWidth) / 2
            imageFrame = CGRect(x: xOffset, y: 0, width: displayWidth, height: viewSize.height)
        }
    }

    /// Converts a point in view coordinates to normalized image coordinates.
    ///
    /// The result is clamped to `0...1` on both axes, so taps in the letterbox
    /// area map to the nearest edge of the image rather than to out-of-range values.
    /// - Parameter viewPoint: A point in the container's coordinate space.
    /// - Returns: A normalized point with a top-left origin.
    func normalizedTopLeft(from viewPoint: CGPoint) -> CGPoint {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return .zero }

        let x = (viewPoint.x - imageFrame.minX) / imageFrame.width
        let y = (viewPoint.y - imageFrame.minY) / imageFrame.height

        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    /// Converts a normalized image point back to view coordinates.
    /// - Parameter normalizedTopLeft: A normalized point with a top-left origin.
    /// - Returns: The corresponding point in the container's coordinate space.
    func viewPoint(fromNormalizedTopLeft normalizedTopLeft: CGPoint) -> CGPoint {
        CGPoint(
            x: imageFrame.minX + normalizedTopLeft.x * imageFrame.width,
            y: imageFrame.minY + normalizedTopLeft.y * imageFrame.height
        )
    }

    /// Converts a normalized rectangle back to view coordinates.
    /// - Parameter normalizedTopLeft: A normalized rectangle with a top-left origin.
    /// - Returns: The corresponding rectangle in the container's coordinate space.
    func viewRect(fromNormalizedTopLeft normalizedTopLeft: CGRect) -> CGRect {
        let origin = viewPoint(fromNormalizedTopLeft: normalizedTopLeft.origin)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: normalizedTopLeft.width * imageFrame.width,
            height: normalizedTopLeft.height * imageFrame.height
        )
    }
}
