import SwiftUI

/// Detail view for the Detect Human Rectangles model
struct DetectHumanRectanglesView: View {
    let model: VisionModel

    @State private var viewModel: DetectHumanRectanglesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectHumanRectanglesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.detectedHumans.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Humans")
                        .font(.headline)

                    Text("\(viewModel.detectedHumans.count) person(s) found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedHumans) { human in
                        HumanRectangleCard(human: human)
                    }
                }
            }
        })
    }
}

// MARK: - Human Rectangle Card

/// Card displaying detected human information
struct HumanRectangleCard: View {
    let human: DetectedHuman

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Person \(human.index + 1)")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", human.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(human.confidence))
            }

            // Bounding box details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Position")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(human.boundingBox.origin.x)), \(Int(human.boundingBox.origin.y)))")
                            .font(.body)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(human.boundingBox.width)) × \(Int(human.boundingBox.height))")
                            .font(.body)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aspect Ratio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", human.aspectRatio))
                            .font(.body)
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
        .accessibilityLabel("Person \(human.index + 1), confidence \(String(format: "%.0f%%", human.confidence * 100))")
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
        DetectHumanRectanglesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectHumanRectangles })!
        )
    }
}
