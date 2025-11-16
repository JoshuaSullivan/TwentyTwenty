import SwiftUI

/// Detail view for the Detect Human Hand Pose model
struct DetectHumanHandPoseView: View {
    let model: VisionModel

    @State private var viewModel: DetectHumanHandPoseViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectHumanHandPoseViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.detectedHands.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Hand Poses")
                        .font(.headline)

                    Text("\(viewModel.detectedHands.count) hand(s) detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedHands) { hand in
                        HandPoseCard(hand: hand)
                    }
                }
            }
        })
    }
}

// MARK: - Hand Pose Card

/// Card displaying hand pose information
struct HandPoseCard: View {
    let hand: HumanHandPose

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(hand.chiralityDescription)
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", hand.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(hand.confidence))
            }

            // Joint count summary
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised")
                        .foregroundStyle(.blue)
                    Text("\(hand.joints.count) joints")
                        .font(.subheadline)
                }

                Divider()
                    .frame(height: 20)

                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.cross")
                        .foregroundStyle(.green)
                    Text("\(hand.jointsByFinger.count) fingers")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)

            // Joints by finger
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Joints")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                let fingerOrder = ["Wrist", "Thumb", "Index", "Middle", "Ring", "Little"]
                ForEach(fingerOrder, id: \.self) { finger in
                    if let joints = hand.jointsByFinger[finger], !joints.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(finger)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.semibold)

                                if finger != "Wrist" {
                                    Image(systemName: fingerIcon(finger))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

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
        .accessibilityLabel("\(hand.chiralityDescription), \(hand.joints.count) joints detected")
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

    private func fingerIcon(_ finger: String) -> String {
        switch finger {
        case "Thumb": return "hand.thumbsup"
        case "Index": return "hand.point.up"
        case "Middle", "Ring", "Little": return "hand.raised"
        default: return "hand.raised"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectHumanHandPoseView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectHumanHandPose })!
        )
    }
}
