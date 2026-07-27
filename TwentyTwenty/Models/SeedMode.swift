import Foundation

/// The seeding interaction offered by the iterative segmentation canvas.
enum SeedMode: String, CaseIterable, Identifiable {
    /// Tap a single point on the object.
    case point

    /// Drag a bounding box around the object.
    case box

    /// Draw freehand over the object.
    case scribble

    var id: String { rawValue }

    /// Short title suitable for a segmented control.
    var title: String {
        switch self {
        case .point: "Point"
        case .box: "Box"
        case .scribble: "Scribble"
        }
    }

    /// Instructional copy shown above the canvas.
    var instruction: String {
        switch self {
        case .point: "Tap the object you want to segment."
        case .box: "Drag a box around the object you want to segment."
        case .scribble: "Draw over the object you want to segment, then lift to run."
        }
    }
}
