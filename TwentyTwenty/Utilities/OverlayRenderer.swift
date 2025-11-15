import UIKit
import CoreGraphics
import Vision

/// Utility for rendering overlay visualizations on images
enum OverlayRenderer {
    // MARK: - Rectangle Overlays

    /// Renders bounding boxes with optional labels on an image
    /// - Parameters:
    ///   - rectangles: Array of rectangles to draw
    ///   - imageSize: Size of the image to render on
    ///   - lineWidth: Width of the rectangle stroke (default: 3)
    /// - Returns: UIImage containing the rendered overlay
    static func renderRectangles(
        _ rectangles: [(rect: CGRect, label: String?)],
        imageSize: CGSize,
        lineWidth: CGFloat = 3
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            let ctx = context.cgContext

            for (rect, label) in rectangles {
                // Draw rectangle (white, will be tinted by the view)
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(lineWidth)
                ctx.stroke(rect)

                // Draw label if provided
                if let labelText = label {
                    drawLabel(labelText, at: rect.minX, y: rect.minY, in: ctx)
                }
            }
        }
    }

    // MARK: - Pose Skeleton Overlays

    /// Renders pose skeletons with joints and connections
    /// - Parameters:
    ///   - poses: Array of poses with joint points and connections
    ///   - imageSize: Size of the image to render on
    /// - Returns: UIImage containing the rendered overlay
    static func renderPoseSkeletons(
        _ poses: [(joints: [CGPoint], connections: [(Int, Int)])],
        imageSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale sizes based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let jointRadius = maxDimension * 0.009  // 0.9% of largest dimension (40% smaller)
        let lineWidth = maxDimension * 0.005    // 0.5% of largest dimension (40% smaller)

        return renderer.image { context in
            let ctx = context.cgContext

            for pose in poses {
                // Draw connections (lines between joints)
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(lineWidth)
                ctx.setLineCap(.round)

                for (fromIndex, toIndex) in pose.connections {
                    guard fromIndex < pose.joints.count,
                          toIndex < pose.joints.count else {
                        continue
                    }

                    let fromPoint = pose.joints[fromIndex]
                    let toPoint = pose.joints[toIndex]

                    ctx.move(to: fromPoint)
                    ctx.addLine(to: toPoint)
                }
                ctx.strokePath()

                // Draw joints (circles at each point)
                ctx.setFillColor(UIColor.white.cgColor)

                for joint in pose.joints {
                    let rect = CGRect(
                        x: joint.x - jointRadius,
                        y: joint.y - jointRadius,
                        width: jointRadius * 2,
                        height: jointRadius * 2
                    )
                    ctx.fillEllipse(in: rect)
                }
            }
        }
    }

    // MARK: - Bitmap/Mask Overlays

    /// Renders a bitmap mask or heatmap overlay
    /// - Parameters:
    ///   - pixelBuffer: CVPixelBuffer containing the mask or heatmap data
    ///   - imageSize: Size of the image to render on
    /// - Returns: UIImage containing the rendered overlay (white where mask is active)
    static func renderBitmapMask(
        _ pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    ) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // Create a white mask from the grayscale image
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { ctx in
            ctx.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))
        }
    }

    // MARK: - Private Helpers

    /// Draws a label with background at the specified position
    private static func drawLabel(_ text: String, at x: CGFloat, y: CGFloat, in ctx: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let labelOrigin = CGPoint(
            x: x,
            y: y - textSize.height - 4
        )

        // Background (white, will be tinted by the view)
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        ctx.fill(CGRect(origin: labelOrigin, size: textSize).insetBy(dx: -4, dy: -2))

        // Text
        attributedString.draw(at: labelOrigin)
    }
}
