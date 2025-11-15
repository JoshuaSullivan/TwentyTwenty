import SwiftUI

/// Protocol for objects that can be drawn as overlays on images
protocol ImageOverlay {
    /// Draw the overlay in the given graphics context
    /// - Parameters:
    ///   - context: The graphics context to draw in
    ///   - imageSize: The size of the underlying image in points
    func draw(in context: inout GraphicsContext, imageSize: CGSize)
}

// MARK: - Rectangle Overlay

/// Overlay for drawing bounding boxes with optional labels
struct RectangleOverlay: ImageOverlay {
    let rectangles: [OverlayRectangle]

    func draw(in context: inout GraphicsContext, imageSize: CGSize) {
        for rectangle in rectangles {
            let rect = rectangle.bounds
            let path = Path(roundedRect: rect, cornerRadius: 4)

            // Draw rectangle stroke
            context.stroke(
                path,
                with: .color(rectangle.color),
                lineWidth: 2
            )

            // Draw label if present
            if let label = rectangle.label {
                drawLabel(label, at: rect.origin, color: rectangle.color, in: &context)
            }
        }
    }

    private func drawLabel(_ text: String, at point: CGPoint, color: Color, in context: inout GraphicsContext) {
        let labelText = Text(text)
            .font(.caption)
            .foregroundStyle(.white)

        let resolved = context.resolve(labelText)
        let labelSize = resolved.measure(in: .init(width: 300, height: 100))

        // Background for label
        let labelRect = CGRect(
            x: point.x,
            y: point.y - labelSize.height - 4,
            width: labelSize.width + 8,
            height: labelSize.height + 4
        )

        context.fill(
            Path(roundedRect: labelRect, cornerRadius: 4),
            with: .color(color.opacity(0.8))
        )

        // Label text
        context.draw(
            resolved,
            at: CGPoint(x: labelRect.midX, y: labelRect.midY),
            anchor: .center
        )
    }
}

/// Represents a single rectangle to be drawn
struct OverlayRectangle: Identifiable {
    let id = UUID()
    let bounds: CGRect
    let color: Color
    let label: String?

    init(bounds: CGRect, color: Color = .blue, label: String? = nil) {
        self.bounds = bounds
        self.color = color
        self.label = label
    }
}

// MARK: - Pose Skeleton Overlay

/// Overlay for drawing pose skeletons with joints and connections
struct PoseSkeletonOverlay: ImageOverlay {
    let skeletons: [PoseSkeleton]

    func draw(in context: inout GraphicsContext, imageSize: CGSize) {
        for skeleton in skeletons {
            // Draw connections first (behind joints)
            for connection in skeleton.connections {
                guard connection.fromIndex < skeleton.joints.count,
                      connection.toIndex < skeleton.joints.count else {
                    continue
                }

                let from = skeleton.joints[connection.fromIndex]
                let to = skeleton.joints[connection.toIndex]

                var path = Path()
                path.move(to: from.point)
                path.addLine(to: to.point)

                context.stroke(
                    path,
                    with: .color(skeleton.color.opacity(from.confidence * to.confidence)),
                    lineWidth: 2
                )
            }

            // Draw joints on top
            for joint in skeleton.joints {
                let rect = CGRect(
                    x: joint.point.x - 4,
                    y: joint.point.y - 4,
                    width: 8,
                    height: 8
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(skeleton.color.opacity(joint.confidence))
                )

                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(joint.confidence)),
                    lineWidth: 1
                )
            }
        }
    }
}

/// Represents a complete pose skeleton
struct PoseSkeleton: Identifiable {
    let id = UUID()
    let joints: [PoseJoint]
    let connections: [JointConnection]
    let color: Color

    init(joints: [PoseJoint], connections: [JointConnection], color: Color = .green) {
        self.joints = joints
        self.connections = connections
        self.color = color
    }
}

/// Represents a single joint point
struct PoseJoint {
    let point: CGPoint
    let confidence: Double

    init(point: CGPoint, confidence: Double = 1.0) {
        self.point = point
        self.confidence = min(max(confidence, 0), 1)
    }
}

/// Represents a connection between two joints
struct JointConnection {
    let fromIndex: Int
    let toIndex: Int
}

// MARK: - Bitmap Overlay

/// Overlay for drawing bitmap masks and heatmaps
struct BitmapOverlay: ImageOverlay {
    let image: UIImage
    let opacity: Double
    let blendMode: GraphicsContext.BlendMode

    init(image: UIImage, opacity: Double = 0.5, blendMode: GraphicsContext.BlendMode = .normal) {
        self.image = image
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
    }

    func draw(in context: inout GraphicsContext, imageSize: CGSize) {
        guard image.cgImage != nil else { return }

        let rect = CGRect(origin: .zero, size: imageSize)

        context.blendMode = blendMode
        context.opacity = opacity

        context.draw(
            Image(uiImage: image),
            in: rect
        )
    }
}

// MARK: - Path Overlay

/// Overlay for drawing arbitrary paths (contours, etc.)
struct PathOverlay: ImageOverlay {
    let paths: [OverlayPath]

    func draw(in context: inout GraphicsContext, imageSize: CGSize) {
        for overlayPath in paths {
            context.stroke(
                overlayPath.path,
                with: .color(overlayPath.color),
                lineWidth: overlayPath.lineWidth
            )
        }
    }
}

/// Represents a single path to be drawn
struct OverlayPath: Identifiable {
    let id = UUID()
    let path: Path
    let color: Color
    let lineWidth: CGFloat

    init(path: Path, color: Color = .yellow, lineWidth: CGFloat = 2) {
        self.path = path
        self.color = color
        self.lineWidth = lineWidth
    }
}

// MARK: - Line Overlay

/// Overlay for drawing single lines (horizon, etc.)
struct LineOverlay: ImageOverlay {
    let lines: [OverlayLine]

    func draw(in context: inout GraphicsContext, imageSize: CGSize) {
        for line in lines {
            var path = Path()
            path.move(to: line.start)
            path.addLine(to: line.end)

            context.stroke(
                path,
                with: .color(line.color),
                lineWidth: line.lineWidth
            )

            // Draw angle label if present
            if let angle = line.angle {
                let midPoint = CGPoint(
                    x: (line.start.x + line.end.x) / 2,
                    y: (line.start.y + line.end.y) / 2
                )

                let labelText = Text(String(format: "%.1f°", angle))
                    .font(.caption)
                    .foregroundStyle(.white)

                let resolved = context.resolve(labelText)
                let labelSize = resolved.measure(in: .init(width: 100, height: 50))

                // Background
                let labelRect = CGRect(
                    x: midPoint.x - labelSize.width / 2 - 4,
                    y: midPoint.y - labelSize.height / 2 - 2,
                    width: labelSize.width + 8,
                    height: labelSize.height + 4
                )

                context.fill(
                    Path(roundedRect: labelRect, cornerRadius: 4),
                    with: .color(line.color.opacity(0.8))
                )

                context.draw(
                    resolved,
                    at: midPoint,
                    anchor: .center
                )
            }
        }
    }
}

/// Represents a single line to be drawn
struct OverlayLine: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
    let angle: Double?

    init(start: CGPoint, end: CGPoint, color: Color = .red, lineWidth: CGFloat = 2, angle: Double? = nil) {
        self.start = start
        self.end = end
        self.color = color
        self.lineWidth = lineWidth
        self.angle = angle
    }
}

// MARK: - Landmark Overlay

/// Overlay for drawing landmark points and contours
struct LandmarkOverlay: ImageOverlay {
    let landmarks: [LandmarkGroup]

    func draw(in context: inout GraphicsContext, imageSize: CGSize) {
        for group in landmarks {
            // Draw contour path if present
            if let contourPath = group.contourPath {
                context.stroke(
                    contourPath,
                    with: .color(group.color),
                    lineWidth: 2
                )
            }

            // Draw individual points
            for point in group.points {
                let rect = CGRect(
                    x: point.x - 3,
                    y: point.y - 3,
                    width: 6,
                    height: 6
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(group.color)
                )
            }
        }
    }
}

/// Represents a group of related landmarks
struct LandmarkGroup: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let contourPath: Path?
    let color: Color
    let label: String?

    init(points: [CGPoint], contourPath: Path? = nil, color: Color = .cyan, label: String? = nil) {
        self.points = points
        self.contourPath = contourPath
        self.color = color
        self.label = label
    }
}

// MARK: - Helper Extensions

extension Color {
    /// Predefined colors for overlays with good contrast
    static let overlayColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .pink, .yellow, .cyan, .mint, .indigo
    ]

    /// Get a color from the overlay palette by index
    static func overlayColor(at index: Int) -> Color {
        overlayColors[index % overlayColors.count]
    }
}
