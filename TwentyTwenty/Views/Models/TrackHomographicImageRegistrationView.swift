import SwiftUI

/// Detail view for the Track Homographic Image Registration model
struct TrackHomographicImageRegistrationView: View {
    let model: VisionModel

    @State private var viewModel: TrackHomographicImageRegistrationViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackHomographicImageRegistrationViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Multiple images requirement notice
            MultipleImagesRequirementNotice(
                title: "Homographic Image Registration",
                description: "Computes a perspective transformation to align two images, accounting for rotation, scale, skew, and perspective changes.",
                capabilities: [
                    "Compute full perspective transformations",
                    "Handle viewpoint changes",
                    "Support rotation and scale differences",
                    "Generate transformation matrices"
                ],
                workflow: [
                    "Provide a reference image and a target image",
                    "Vision analyzes feature correspondences between images",
                    "A homography matrix is computed",
                    "The matrix can transform one image to align with the other"
                ],
                useCases: [
                    "Image stitching and panoramas",
                    "Document perspective correction",
                    "Augmented reality alignment",
                    "Multi-view image alignment"
                ]
            )
        })
    }
}

// MARK: - Multiple Images Requirement Notice

/// Reusable component for models requiring multiple images
struct MultipleImagesRequirementNotice: View {
    let title: String
    let description: String
    let capabilities: [String]
    let workflow: [String]
    let useCases: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(.purple)

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
                                .foregroundStyle(.purple)
                                .frame(width: 24, alignment: .trailing)

                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Use cases
            VStack(alignment: .leading, spacing: 12) {
                Text("Common Use Cases")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(useCases, id: \.self) { useCase in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .frame(width: 16)

                            Text(useCase)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Multiple images requirement notice
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("This model requires two images for registration and cannot be demonstrated with a single static image.")
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
        TrackHomographicImageRegistrationView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackHomographicImageRegistration })!
        )
    }
}
