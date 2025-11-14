import SwiftUI

/// Detail view for the Generate Person Instance Mask model
struct GeneratePersonInstanceMaskView: View {
    let model: VisionModel

    @State private var viewModel: GeneratePersonInstanceMaskViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GeneratePersonInstanceMaskViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.personInstances.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Person Instance Masks")
                        .font(.headline)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.square")
                                .foregroundStyle(.blue)
                            let totalInstances = viewModel.personInstances.reduce(0) { $0 + $1.instanceCount }
                            Text("\(totalInstances) person(s)")
                                .font(.subheadline)
                        }

                        Divider()
                            .frame(height: 20)

                        HStack(spacing: 6) {
                            Image(systemName: "square.on.square.dashed")
                                .foregroundStyle(.green)
                            Text("Instance segmentation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    ForEach(viewModel.personInstances) { instance in
                        PersonInstanceCard(instance: instance)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Person Instance Masks")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model generates pixel-accurate segmentation masks for each individual person in an image. Unlike person segmentation which treats all people as one class, instance masks separate each person into distinct instances. The masks can be used for background removal, image editing, or person counting.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        })
    }
}

// MARK: - Person Instance Card

/// Card displaying person instance information
struct PersonInstanceCard: View {
    let instance: PersonInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.blue)
                    Text("Mask \(instance.index + 1)")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", instance.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(instance.confidence))
            }

            // Instance details
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Instances Detected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.blue)
                            Text("\(instance.instanceCount)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Divider()

                Text("Each person in the image has been assigned a unique instance mask, allowing for individual segmentation and manipulation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Person instance mask, \(instance.instanceCount) people detected")
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.9 {
            return .green
        } else if confidence > 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeneratePersonInstanceMaskView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .generatePersonInstanceMask })!
        )
    }
}
