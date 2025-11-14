import SwiftUI

/// Detail view for the Detect Trajectories model
struct DetectTrajectoriesView: View {
    let model: VisionModel

    @State private var viewModel: DetectTrajectoriesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectTrajectoriesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Video requirement notice
            VideoRequirementNotice(
                title: "Trajectory Detection",
                description: "Analyzes motion paths of objects across video frames, detecting and characterizing complex movement patterns.",
                capabilities: [
                    "Detect parabolic trajectories (thrown objects)",
                    "Identify linear motion paths",
                    "Analyze curved movement patterns",
                    "Predict future positions based on trajectory"
                ],
                workflow: [
                    "Provide a sequence of video frames",
                    "Vision tracks objects through the sequence",
                    "Movement patterns are analyzed",
                    "Trajectory paths and characteristics are returned"
                ]
            )
        })
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectTrajectoriesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectTrajectories })!
        )
    }
}
