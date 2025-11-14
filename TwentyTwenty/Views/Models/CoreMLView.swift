import SwiftUI

/// Detail view for the Core ML Request model
struct CoreMLView: View {
    let model: VisionModel

    @State private var viewModel: CoreMLViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: CoreMLViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Core ML requirement notice
            CoreMLRequirementNotice()
        })
    }
}

// MARK: - Core ML Requirement Notice

/// Notice explaining Core ML model requirement
struct CoreMLRequirementNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.title2)
                        .foregroundStyle(.indigo)

                    Text("Core ML Integration")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Text("Integrate custom machine learning models with Vision's image analysis pipeline.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // What is Core ML
            VStack(alignment: .leading, spacing: 12) {
                Text("About Core ML")
                    .font(.headline)

                Text("Core ML is Apple's framework for integrating machine learning models into apps. Vision's Core ML request allows you to use custom trained models for specialized image analysis tasks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Capabilities
            VStack(alignment: .leading, spacing: 12) {
                Text("Capabilities")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    CoreMLCapabilityRow(icon: "photo", text: "Custom image classification")
                    CoreMLCapabilityRow(icon: "viewfinder", text: "Object detection with custom classes")
                    CoreMLCapabilityRow(icon: "lasso", text: "Instance segmentation")
                    CoreMLCapabilityRow(icon: "puzzlepiece.extension", text: "Integration with Vision pipeline")
                }
            }

            Divider()

            // Getting models
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Get Core ML Models")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    CoreMLSourceRow(
                        number: 1,
                        title: "Create ML",
                        description: "Train custom models using Apple's Create ML app"
                    )

                    CoreMLSourceRow(
                        number: 2,
                        title: "Model Gallery",
                        description: "Download pre-trained models from Apple's Core ML model gallery"
                    )

                    CoreMLSourceRow(
                        number: 3,
                        title: "Third Party",
                        description: "Convert models from TensorFlow, PyTorch, or other frameworks"
                    )
                }
            }

            Divider()

            // Example workflow
            VStack(alignment: .leading, spacing: 12) {
                Text("Example Workflow")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(workflowSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                                .frame(width: 24, alignment: .trailing)

                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Links
            VStack(alignment: .leading, spacing: 12) {
                Text("Resources")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: URL(string: "https://developer.apple.com/machine-learning/models/")!) {
                        HStack {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("Core ML Model Gallery")
                                .font(.subheadline)
                        }
                    }

                    Link(destination: URL(string: "https://developer.apple.com/documentation/createml")!) {
                        HStack {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("Create ML Documentation")
                                .font(.subheadline)
                        }
                    }

                    Link(destination: URL(string: "https://developer.apple.com/documentation/vision/vncoremlrequest")!) {
                        HStack {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("VNCoreMLRequest Documentation")
                                .font(.subheadline)
                        }
                    }
                }
            }

            Divider()

            // User model requirement notice
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("This model requires a user-provided Core ML model file and cannot be demonstrated without one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }

    private let workflowSteps = [
        "Add a .mlmodel file to your Xcode project",
        "Create a VNCoreMLModel from your Core ML model",
        "Initialize a VNCoreMLRequest with the model",
        "Process images through the Vision pipeline",
        "Receive predictions and classifications"
    ]
}

// MARK: - Core ML Capability Row

struct CoreMLCapabilityRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
                .frame(width: 16)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Core ML Source Row

struct CoreMLSourceRow: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.indigo)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CoreMLView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .coreML })!
        )
    }
}
