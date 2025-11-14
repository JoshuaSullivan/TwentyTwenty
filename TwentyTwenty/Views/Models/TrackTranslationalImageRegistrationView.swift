import SwiftUI

/// Detail view for the Track Translational Image Registration model
struct TrackTranslationalImageRegistrationView: View {
    let model: VisionModel

    @State private var viewModel: TrackTranslationalImageRegistrationViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackTranslationalImageRegistrationViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Multiple images requirement notice
            MultipleImagesRequirementNotice(
                title: "Translational Image Registration",
                description: "Computes a simple x/y translation offset to align two images that differ only in position.",
                capabilities: [
                    "Fast alignment computation",
                    "Precise pixel-level alignment",
                    "Efficient for camera shake correction",
                    "Generate translation vectors"
                ],
                workflow: [
                    "Provide a reference image and a target image",
                    "Vision analyzes feature correspondences",
                    "An x/y translation offset is computed",
                    "The offset can be applied to align the images"
                ],
                useCases: [
                    "Camera shake stabilization",
                    "Time-lapse alignment",
                    "Image stacking for noise reduction",
                    "Motion detection in static scenes"
                ]
            )
        })
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackTranslationalImageRegistrationView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackTranslationalImageRegistration })!
        )
    }
}
