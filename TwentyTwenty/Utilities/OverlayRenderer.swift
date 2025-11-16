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

    // MARK: - Line Overlays

    /// Renders a horizon line overlay
    /// - Parameters:
    ///   - angle: Angle of the horizon line in radians
    ///   - imageSize: Size of the image to render on
    /// - Returns: UIImage containing the rendered overlay
    static func renderHorizonLine(
        angle: Double,
        imageSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale line width based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let lineWidth = maxDimension * 0.003  // 0.3% of largest dimension

        return renderer.image { context in
            let ctx = context.cgContext

            // Calculate horizon line endpoints
            // The horizon passes through the center of the image
            let centerX = imageSize.width / 2
            let centerY = imageSize.height / 2

            // Calculate line endpoints extending to image edges
            let length = maxDimension * 2
            let dx = cos(angle) * length / 2
            let dy = sin(angle) * length / 2

            let startPoint = CGPoint(x: centerX - dx, y: centerY - dy)
            let endPoint = CGPoint(x: centerX + dx, y: centerY + dy)

            // Draw horizon line
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)

            ctx.move(to: startPoint)
            ctx.addLine(to: endPoint)
            ctx.strokePath()
        }
    }

    // MARK: - Path Overlays

    /// Renders contour paths overlay
    /// - Parameters:
    ///   - contours: Array of contour paths to draw
    ///   - imageSize: Size of the image to render on
    /// - Returns: UIImage containing the rendered overlay
    static func renderContours(
        _ contours: [VNContour],
        imageSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale line width based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let lineWidth = maxDimension * 0.002  // 0.2% of largest dimension

        return renderer.image { context in
            let ctx = context.cgContext

            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            for contour in contours {
                drawContourPath(contour, imageSize: imageSize, in: ctx)
            }
        }
    }

    /// Renders face landmarks as points and contours
    /// - Parameters:
    ///   - landmarks: Face landmarks to render
    ///   - boundingBox: Face bounding box for coordinate conversion
    ///   - imageSize: Size of the image to render on
    /// - Returns: UIImage containing the rendered overlay
    static func renderFaceLandmarks(
        _ landmarks: VNFaceLandmarks2D,
        boundingBox: CGRect,
        imageSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale sizes based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let pointRadius = maxDimension * 0.003  // 0.3% of largest dimension
        let lineWidth = maxDimension * 0.002    // 0.2% of largest dimension

        return renderer.image { context in
            let ctx = context.cgContext

            // Draw contours (connected points)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let landmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.faceContour,
                landmarks.leftEye,
                landmarks.rightEye,
                landmarks.leftEyebrow,
                landmarks.rightEyebrow,
                landmarks.nose,
                landmarks.noseCrest,
                landmarks.outerLips,
                landmarks.innerLips
            ]

            for region in landmarkRegions.compactMap({ $0 }) {
                drawLandmarkRegion(region, boundingBox: boundingBox, imageSize: imageSize, in: ctx)
            }

            // Draw individual points
            ctx.setFillColor(UIColor.white.cgColor)

            for region in landmarkRegions.compactMap({ $0 }) {
                for point in region.normalizedPoints {
                    let imagePoint = convertLandmarkPoint(point, boundingBox: boundingBox, imageSize: imageSize)
                    let rect = CGRect(
                        x: imagePoint.x - pointRadius,
                        y: imagePoint.y - pointRadius,
                        width: pointRadius * 2,
                        height: pointRadius * 2
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

    /// Draws a contour path
    private static func drawContourPath(_ contour: VNContour, imageSize: CGSize, in ctx: CGContext) {
        let points = contour.normalizedPoints

        guard !points.isEmpty else { return }

        // Convert first point to image coordinates
        let firstPoint = CGPoint(
            x: CGFloat(points[0].x) * imageSize.width,
            y: (1 - CGFloat(points[0].y)) * imageSize.height
        )

        ctx.move(to: firstPoint)

        // Draw lines to subsequent points
        for i in 1..<points.count {
            let point = CGPoint(
                x: CGFloat(points[i].x) * imageSize.width,
                y: (1 - CGFloat(points[i].y)) * imageSize.height
            )
            ctx.addLine(to: point)
        }

        // Close the path if this is a closed contour
        ctx.closePath()
        ctx.strokePath()
    }

    /// Draws a landmark region (connected points)
    private static func drawLandmarkRegion(
        _ region: VNFaceLandmarkRegion2D,
        boundingBox: CGRect,
        imageSize: CGSize,
        in ctx: CGContext
    ) {
        let points = region.normalizedPoints

        guard points.count > 1 else { return }

        let firstPoint = convertLandmarkPoint(points[0], boundingBox: boundingBox, imageSize: imageSize)
        ctx.move(to: firstPoint)

        for i in 1..<points.count {
            let point = convertLandmarkPoint(points[i], boundingBox: boundingBox, imageSize: imageSize)
            ctx.addLine(to: point)
        }

        ctx.strokePath()
    }

    /// Converts a normalized landmark point to image coordinates
    private static func convertLandmarkPoint(
        _ point: CGPoint,
        boundingBox: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        // Landmark points are relative to the face bounding box
        // First convert to bounding box coordinates, then to image coordinates
        let x = boundingBox.origin.x + point.x * boundingBox.width
        let y = boundingBox.origin.y + (1 - point.y) * boundingBox.height

        return CGPoint(x: x, y: y)
    }

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
