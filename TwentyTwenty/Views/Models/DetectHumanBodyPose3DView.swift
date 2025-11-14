import SwiftUI

/// Detail view for the Detect Human Body Pose 3D model
struct DetectHumanBodyPose3DView: View {
    let model: VisionModel

    @State private var viewModel: DetectHumanBodyPose3DViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectHumanBodyPose3DViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.detectedPoses.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected 3D Body Poses")
                        .font(.headline)

                    Text("\(viewModel.detectedPoses.count) person(s) detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedPoses) { pose in
                        BodyPose3DCard(pose: pose)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About 3D Body Pose Detection")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model detects body joint positions in 3D space, providing depth information along with 2D coordinates. The 3D positions are represented as transformation matrices in the camera's coordinate system.")
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

// MARK: - Body Pose 3D Card

/// Card displaying 3D body pose information
struct BodyPose3DCard: View {
    let pose: HumanBodyPose3D

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.stand")
                        .foregroundStyle(.blue)
                    Text("Person \(pose.index + 1)")
                        .font(.headline)
                }

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
                    Image(systemName: "cube")
                        .foregroundStyle(.blue)
                    Text("\(pose.joints.count) 3D joints")
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

            // Joints by category with 3D coordinates
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Joints (3D Positions)")
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(joint.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    HStack(spacing: 12) {
                                        CoordinateLabel(axis: "X", value: joint.coordinates.x)
                                        CoordinateLabel(axis: "Y", value: joint.coordinates.y)
                                        CoordinateLabel(axis: "Z", value: joint.coordinates.z)
                                    }
                                    .font(.caption2)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
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
        .accessibilityLabel("Person \(pose.index + 1), \(pose.joints.count) 3D joints detected")
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

// MARK: - Coordinate Label

/// Helper view to display a single 3D coordinate
struct CoordinateLabel: View {
    let axis: String
    let value: Float

    var body: some View {
        HStack(spacing: 2) {
            Text(axis + ":")
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f", value))
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectHumanBodyPose3DView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectHumanBodyPose3D })!
        )
    }
}
