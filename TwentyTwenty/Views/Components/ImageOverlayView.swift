import SwiftUI

/// View that displays an image with optional overlays rendered on top
struct ImageOverlayView: View {
    /// The base image to display
    let image: UIImage

    /// Array of overlays to render on top of the image
    let overlays: [ImageOverlay]

    /// Whether to show the overlays
    let showOverlay: Bool

    /// Opacity for bitmap overlays (0.0 to 1.0)
    let overlayOpacity: Double

    init(
        image: UIImage,
        overlays: [ImageOverlay] = [],
        showOverlay: Bool = true,
        overlayOpacity: Double = 0.5
    ) {
        self.image = image
        self.overlays = overlays
        self.showOverlay = showOverlay
        self.overlayOpacity = overlayOpacity
    }

    var body: some View {
        GeometryReader { geometry in
            let imageSize = calculateImageSize(in: geometry.size)
            let imageRect = calculateImageRect(imageSize: imageSize, containerSize: geometry.size)

            ZStack {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Overlays rendered via Canvas
                if showOverlay && !overlays.isEmpty {
                    Canvas { context, size in
                        // Clip to image bounds
                        context.clip(to: Path(imageRect))

                        // Translate context to image origin
                        context.translateBy(x: imageRect.origin.x, y: imageRect.origin.y)

                        // Draw each overlay
                        for overlay in overlays {
                            var overlayContext = context
                            overlay.draw(in: &overlayContext, imageSize: imageSize)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Image with \(showOverlay ? "overlays visible" : "overlays hidden")")
    }

    // MARK: - Helper Methods

    /// Calculate the actual size the image will be displayed at (maintaining aspect ratio)
    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    /// Calculate the rectangle where the image will actually be drawn (centered)
    private func calculateImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        let x = (containerSize.width - imageSize.width) / 2
        let y = (containerSize.height - imageSize.height) / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: imageSize)
    }
}

// MARK: - Coordinate Conversion Helpers

extension CGRect {
    /// Convert from Vision's normalized coordinates (0-1, origin bottom-left) to SwiftUI coordinates
    /// - Parameters:
    ///   - imageSize: The size of the image in points
    /// - Returns: Rectangle in SwiftUI coordinate space
    static func fromVisionRect(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: visionRect.origin.x * imageSize.width,
            y: (1 - visionRect.origin.y - visionRect.height) * imageSize.height,
            width: visionRect.width * imageSize.width,
            height: visionRect.height * imageSize.height
        )
    }
}

extension CGPoint {
    /// Convert from Vision's normalized coordinates (0-1, origin bottom-left) to SwiftUI coordinates
    /// - Parameters:
    ///   - imageSize: The size of the image in points
    /// - Returns: Point in SwiftUI coordinate space
    static func fromVisionPoint(_ visionPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: visionPoint.x * imageSize.width,
            y: (1 - visionPoint.y) * imageSize.height
        )
    }
}

// MARK: - Preview

#Preview("Rectangle Overlay") {
    if let sampleImage = UIImage(systemName: "photo.fill")?.withTintColor(.gray, renderingMode: .alwaysOriginal) {
        ImageOverlayView(
            image: sampleImage,
            overlays: [
                RectangleOverlay(rectangles: [
                    OverlayRectangle(
                        bounds: CGRect(x: 50, y: 50, width: 100, height: 100),
                        color: .blue,
                        label: "Test"
                    )
                ])
            ],
            showOverlay: true
        )
        .frame(height: 300)
        .padding()
    }
}

#Preview("Pose Skeleton Overlay") {
    if let sampleImage = UIImage(systemName: "photo.fill")?.withTintColor(.gray, renderingMode: .alwaysOriginal) {
        let joints = [
            PoseJoint(point: CGPoint(x: 100, y: 100), confidence: 1.0),
            PoseJoint(point: CGPoint(x: 150, y: 150), confidence: 0.9),
            PoseJoint(point: CGPoint(x: 100, y: 200), confidence: 0.8)
        ]

        let connections = [
            JointConnection(fromIndex: 0, toIndex: 1),
            JointConnection(fromIndex: 1, toIndex: 2)
        ]

        ImageOverlayView(
            image: sampleImage,
            overlays: [
                PoseSkeletonOverlay(skeletons: [
                    PoseSkeleton(joints: joints, connections: connections, color: .green)
                ])
            ],
            showOverlay: true
        )
        .frame(height: 300)
        .padding()
    }
}
