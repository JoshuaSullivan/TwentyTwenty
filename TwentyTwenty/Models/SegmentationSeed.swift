import CoreGraphics

/// How the user seeded an iterative segmentation.
///
/// All coordinates are normalized with a **top-left origin**, matching SwiftUI.
/// Conversion to Vision's bottom-left origin happens only at the boundary where
/// values are handed to the request.
enum SegmentationSeed: Equatable {
    /// A single tapped point.
    case point(CGPoint)

    /// A dragged bounding box.
    case box(CGRect)

    /// One or more freehand strokes, each an ordered list of points.
    case scribble([[CGPoint]])
}
