import SwiftUI

/// Detail view for the Generate Objectness-Based Saliency Image model
struct GenerateObjectnessBasedSaliencyImageView: View {
    let model: VisionModel

    @State private var viewModel: GenerateObjectnessBasedSaliencyImageViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GenerateObjectnessBasedSaliencyImageViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.saliencyResults.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Objectness-Based Saliency Analysis")
                        .font(.headline)

                    ForEach(viewModel.saliencyResults) { result in
                        ObjectnessSaliencyResultCard(result: result)
                    }

                    // Info about objectness-based saliency
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Objectness-Based Saliency")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model identifies regions likely to contain distinct, recognizable objects. Unlike attention-based saliency which focuses on visual appeal, objectness highlights areas with clear object boundaries and shapes.")
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

// MARK: - Objectness Saliency Result Card

/// Card displaying objectness saliency analysis results
struct ObjectnessSaliencyResultCard: View {
    let result: ObjectnessSaliency

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Saliency Map")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", result.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(result.confidence))
            }

            if !result.salientObjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(result.salientObjects.count) Object Region\(result.salientObjects.count == 1 ? "" : "s") Detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(result.salientObjects) { object in
                        ObjectnessRegionRow(object: object)
                    }
                }
            } else {
                Text("No discrete object regions identified")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Objectness saliency map with confidence \(String(format: "%.0f%%", result.confidence * 100)), \(result.salientObjects.count) object regions")
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

// MARK: - Objectness Region Row

/// Row displaying an object region
struct ObjectnessRegionRow: View {
    let object: SalientObject

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Object \(object.index + 1)")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Position")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(object.boundingBox.origin.x)), \(Int(object.boundingBox.origin.y)))")
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Size")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(object.boundingBox.width)) × \(Int(object.boundingBox.height))")
                            .font(.caption)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", object.confidence * 100))
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenerateObjectnessBasedSaliencyImageView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .generateObjectnessBasedSaliencyImage })!
        )
    }
}
