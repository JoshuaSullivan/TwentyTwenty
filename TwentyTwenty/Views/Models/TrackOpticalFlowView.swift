import SwiftUI

/// Detail view for the Track Optical Flow model
struct TrackOpticalFlowView: View {
    let model: VisionModel

    @State private var viewModel: TrackOpticalFlowViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackOpticalFlowViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Video requirement notice
            VideoRequirementNotice(
                title: "Optical Flow",
                description: "Optical flow computes dense motion vectors between consecutive frames, revealing how every pixel moves in the scene.",
                capabilities: [
                    "Generate dense motion vector fields",
                    "Detect camera motion vs object motion",
                    "Analyze movement patterns and speed",
                    "Support motion-based video effects"
                ],
                workflow: [
                    "Provide two consecutive video frames",
                    "Vision analyzes pixel-level changes between frames",
                    "Motion vectors are computed for the image",
                    "Results show direction and magnitude of motion"
                ]
            )
        })
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackOpticalFlowView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackOpticalFlow })!
        )
    }
}
