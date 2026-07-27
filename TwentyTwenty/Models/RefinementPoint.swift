import CoreGraphics
import Foundation

/// A single refinement point placed by the user after seeding a segmentation.
struct RefinementPoint: Identifiable, Equatable {
    let id = UUID()

    /// Location in normalized image coordinates, top-left origin.
    let location: CGPoint

    /// Whether this point includes or excludes the region it sits on.
    let polarity: RefinementPolarity
}
