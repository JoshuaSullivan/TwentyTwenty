import SwiftUI

/// Detail view for the Track Rectangle model
struct TrackRectangleView: View {
    let model: VisionModel

    @State private var viewModel: TrackRectangleViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackRectangleViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Video requirement notice
            VideoRequirementNotice(
                title: "Rectangle Tracking",
                description: "Rectangle tracking maintains a rectangular region across video frames, adapting to perspective changes and motion.",
                capabilities: [
                    "Track planar rectangular surfaces",
                    "Handle perspective transformations",
                    "Adapt to scale and rotation changes",
                    "Maintain tracking through partial occlusion"
                ],
                workflow: [
                    "Define a rectangular region in the first frame",
                    "Vision establishes tracking features within the rectangle",
                    "Each frame is analyzed to locate the tracked rectangle",
                    "Rectangle corners are updated to match perspective changes"
                ]
            )
        })
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackRectangleView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackRectangle })!
        )
    }
}
