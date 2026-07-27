import Foundation

/// Whether a refinement point adds to or removes from a segmented region.
enum RefinementPolarity: String, CaseIterable, Identifiable {
    /// The point marks a region that belongs to the object.
    case include

    /// The point marks a region that does not belong to the object.
    case exclude

    var id: String { rawValue }

    /// Short title suitable for a segmented control.
    var title: String {
        switch self {
        case .include: "Include"
        case .exclude: "Exclude"
        }
    }

    /// SF Symbol used for the on-canvas marker.
    var systemImage: String {
        switch self {
        case .include: "plus"
        case .exclude: "minus"
        }
    }
}
