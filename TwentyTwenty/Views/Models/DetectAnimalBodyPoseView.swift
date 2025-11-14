import SwiftUI

/// Detail view for the Detect Animal Body Pose model
struct DetectAnimalBodyPoseView: View {
    let model: VisionModel

    @State private var viewModel: DetectAnimalBodyPoseViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectAnimalBodyPoseViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.detectedPoses.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Animal Poses")
                        .font(.headline)

                    Text("\(viewModel.detectedPoses.count) animal(s) detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedPoses) { pose in
                        AnimalPoseCard(pose: pose)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Animal Pose Detection")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model detects body joint positions for cats and dogs, including ears, eyes, nose, legs, paws, and tail. Best results with clear, full-body images of animals.")
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

// MARK: - Animal Pose Card

/// Card displaying animal pose information
struct AnimalPoseCard: View {
    let pose: AnimalBodyPose

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Animal \(pose.index + 1)")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", pose.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(pose.confidence))
            }

            // Joint count summary
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.blue)
                    Text("\(pose.joints.count) joints")
                        .font(.subheadline)
                }

                Divider()
                    .frame(height: 20)

                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.cross")
                        .foregroundStyle(.green)
                    Text("\(pose.jointsByCategory.count) categories")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)

            // Joints by category
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Joints")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(Array(pose.jointsByCategory.keys.sorted()), id: \.self) { category in
                    if let joints = pose.jointsByCategory[category], !joints.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)

                            ForEach(joints) { joint in
                                HStack {
                                    Circle()
                                        .fill(confidenceColor(joint.confidence))
                                        .frame(width: 8, height: 8)

                                    Text(joint.displayName)
                                        .font(.caption)

                                    Spacer()

                                    Text(String(format: "%.0f%%", joint.confidence * 100))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Animal \(pose.index + 1), \(pose.joints.count) joints detected")
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
        DetectAnimalBodyPoseView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectAnimalBodyPose })!
        )
    }
}
