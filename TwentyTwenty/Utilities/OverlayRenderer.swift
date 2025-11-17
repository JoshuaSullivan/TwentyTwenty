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
    ///   - color: Color for the rectangles (default: white)
    /// - Returns: UIImage containing the rendered overlay
    static func renderRectangles(
        _ rectangles: [(rect: CGRect, label: String?)],
        imageSize: CGSize,
        lineWidth: CGFloat = 3,
        color: UIColor = .white
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            let ctx = context.cgContext

            for (rect, label) in rectangles {
                // Draw rectangle
                ctx.setStrokeColor(color.cgColor)
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

    /// Represents a group of joints with a specific color
    struct JointGroup {
        let connections: [(Int, Int)]
        let color: UIColor
    }

    /// Renders pose skeletons with colored joint groups
    /// - Parameters:
    ///   - poses: Array of poses with joint points and colored joint groups
    ///   - imageSize: Size of the image to render on
    /// - Returns: UIImage containing the rendered overlay
    static func renderPoseSkeletons(
        _ poses: [(joints: [CGPoint], groups: [JointGroup])],
        imageSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale sizes based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let jointRadius = maxDimension * 0.009  // 0.9% of largest dimension
        let lineWidth = maxDimension * 0.005    // 0.5% of largest dimension

        return renderer.image { context in
            let ctx = context.cgContext

            for pose in poses {
                // Draw connections by group (each group has its own color)
                ctx.setLineWidth(lineWidth)
                ctx.setLineCap(.round)

                for group in pose.groups {
                    ctx.setStrokeColor(group.color.cgColor)

                    for (fromIndex, toIndex) in group.connections {
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
                }

                // Draw joints (circles at each point) - use same color as their group
                for group in pose.groups {
                    ctx.setFillColor(group.color.cgColor)

                    // Get unique joints from this group's connections
                    var groupJointIndices = Set<Int>()
                    for (from, to) in group.connections {
                        groupJointIndices.insert(from)
                        groupJointIndices.insert(to)
                    }

                    for jointIndex in groupJointIndices {
                        guard jointIndex < pose.joints.count else { continue }
                        let joint = pose.joints[jointIndex]

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
    }

    // MARK: - Line Overlays

    /// Renders a horizon line overlay
    /// - Parameters:
    ///   - angle: Angle of the horizon line in radians
    ///   - imageSize: Size of the image to render on
    ///   - color: Color for the line (default: white)
    /// - Returns: UIImage containing the rendered overlay
    static func renderHorizonLine(
        angle: Double,
        imageSize: CGSize,
        color: UIColor = .white
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
            ctx.setStrokeColor(color.cgColor)
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
    ///   - color: Color for the contours (default: white)
    /// - Returns: UIImage containing the rendered overlay
    static func renderContours(
        _ contours: [ContoursObservation.Contour],
        imageSize: CGSize,
        color: UIColor = .white
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale line width based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let lineWidth = maxDimension * 0.002  // 0.2% of largest dimension

        return renderer.image { context in
            let ctx = context.cgContext

            ctx.setStrokeColor(color.cgColor)
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
    ///   - visionBoundingBox: Face bounding box in Vision coordinates for landmark conversion
    ///   - imageSize: Size of the image to render on
    ///   - color: Color for the landmarks (default: white)
    /// - Returns: UIImage containing the rendered overlay
    static func renderFaceLandmarks(
        _ landmarks: FaceObservation.Landmarks2D,
        visionBoundingBox: NormalizedRect,
        imageSize: CGSize,
        color: UIColor = .white
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        // Scale sizes based on image dimensions
        let maxDimension = max(imageSize.width, imageSize.height)
        let pointRadius = maxDimension * 0.003  // 0.3% of largest dimension
        let lineWidth = maxDimension * 0.002    // 0.2% of largest dimension

        return renderer.image { context in
            let ctx = context.cgContext

            // Draw contours (connected points)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let landmarkRegions: [FaceObservation.Landmarks2D.Region] = [
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

            for region in landmarkRegions.filter({ !$0.points.isEmpty }) {
                drawLandmarkRegion(region, visionBoundingBox: visionBoundingBox, imageSize: imageSize, in: ctx)
            }

            // Draw individual points
            ctx.setFillColor(color.cgColor)

            for region in landmarkRegions.filter({ !$0.points.isEmpty }) {
                for point in region.points {
                    let imagePoint = convertLandmarkPoint(point, visionBoundingBox: visionBoundingBox, imageSize: imageSize)
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

    /// Renders a bitmap mask with a tint color overlay
    /// - Parameters:
    ///   - pixelBuffer: CVPixelBuffer containing the mask data
    ///   - imageSize: Size of the image to render on
    ///   - tintColor: Color to apply where mask is white (black areas will be transparent)
    ///   - flipVertically: Whether to flip the mask vertically (for Vision coordinate conversion)
    /// - Returns: UIImage containing the rendered colored mask overlay
    static func renderBitmapMask(
        _ pixelBuffer: CVPixelBuffer,
        imageSize: CGSize,
        tintColor: UIColor,
        flipVertically: Bool = false
    ) async -> UIImage? {
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Flip vertically if needed (Vision coordinates use bottom-left origin, UIKit uses top-left)
        if flipVertically {
            ciImage = ciImage.oriented(.downMirrored)
        }

        // Apply color matrix to convert grayscale to tinted mask
        // White (1) becomes the tint color, black (0) becomes transparent
        guard let colorMatrixFilter = CIFilter(name: "CIColorMatrix") else {
            return nil
        }

        // Extract RGB components from tint color
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        tintColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        colorMatrixFilter.setValue(ciImage, forKey: kCIInputImageKey)
        // Set RGB channels based on tint color, alpha channel uses the mask value
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: red), forKey: "inputRVector")
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: green), forKey: "inputGVector")
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: blue), forKey: "inputBVector")
        colorMatrixFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputAVector")

        guard let outputImage = colorMatrixFilter.outputImage else {
            return nil
        }

        // Scale to match image size
        let scaleX = imageSize.width / outputImage.extent.width
        let scaleY = imageSize.height / outputImage.extent.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Use shared render service for efficient rendering
        return await RenderService.shared.renderToUIImage(image: scaledImage, from: CGRect(origin: .zero, size: imageSize))
    }

    // MARK: - Private Helpers

    /// Draws a contour path
    private static func drawContourPath(_ contour: ContoursObservation.Contour, imageSize: CGSize, in ctx: CGContext) {
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
        _ region: FaceObservation.Landmarks2D.Region,
        visionBoundingBox: NormalizedRect,
        imageSize: CGSize,
        in ctx: CGContext
    ) {
        let points = region.points

        guard points.count > 1 else { return }

        let firstPoint = convertLandmarkPoint(points[0], visionBoundingBox: visionBoundingBox, imageSize: imageSize)
        ctx.move(to: firstPoint)

        for i in 1..<points.count {
            let point = convertLandmarkPoint(points[i], visionBoundingBox: visionBoundingBox, imageSize: imageSize)
            ctx.addLine(to: point)
        }

        ctx.strokePath()
    }

    /// Converts a normalized landmark point to image coordinates
    private static func convertLandmarkPoint(
        _ point: NormalizedPoint,
        visionBoundingBox: NormalizedRect,
        imageSize: CGSize
    ) -> CGPoint {
        // Manual conversion matching createwithswift.com approach:
        // 1. Convert landmark point from normalized (0-1) to bounding box space
        let cgPoint = point.cgPoint
        let x = visionBoundingBox.origin.x + cgPoint.x * visionBoundingBox.width
        let y = visionBoundingBox.origin.y + cgPoint.y * visionBoundingBox.height

        // 2. Flip y-axis (Vision uses lowerLeft, UIKit uses upperLeft) and scale to image size
        return CGPoint(
            x: x * imageSize.width,
            y: y * imageSize.height
        )
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
