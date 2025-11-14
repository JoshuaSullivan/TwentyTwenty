import SwiftUI

/// Detail view for the Track Object model
struct TrackObjectView: View {
    let model: VisionModel

    @State private var viewModel: TrackObjectViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackObjectViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Video requirement notice
            VideoRequirementNotice(
                title: "Object Tracking",
                description: "Object tracking follows the position and movement of objects across video frames in real-time.",
                capabilities: [
                    "Track objects through occlusion",
                    "Maintain tracking across viewpoint changes",
                    "Handle scale and rotation changes",
                    "Support multiple simultaneous tracks"
                ],
                workflow: [
                    "Select an object in the first frame by drawing a bounding box",
                    "Vision analyzes the object's appearance",
                    "Subsequent frames are processed to locate the object",
                    "Tracking updates provide new bounding boxes for each frame"
                ]
            )
        })
    }
}

// MARK: - Video Requirement Notice

/// Reusable component for models requiring video input
struct VideoRequirementNotice: View {
    let title: String
    let description: String
    let capabilities: [String]
    let workflow: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Capabilities
            VStack(alignment: .leading, spacing: 12) {
                Text("Capabilities")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(capabilities, id: \.self) { capability in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .frame(width: 16)

                            Text(capability)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Workflow
            VStack(alignment: .leading, spacing: 12) {
                Text("Typical Workflow")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(workflow.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .frame(width: 24, alignment: .trailing)

                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Video requirement notice
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("This model requires video input and cannot be demonstrated with static images.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackObjectView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackObject })!
        )
    }
}
