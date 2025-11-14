import SwiftUI

/// Detail view for the Generate Attention-Based Saliency Image model
struct GenerateAttentionBasedSaliencyImageView: View {
    let model: VisionModel

    @State private var viewModel: GenerateAttentionBasedSaliencyImageViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GenerateAttentionBasedSaliencyImageViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.saliencyResults.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Attention-Based Saliency Analysis")
                        .font(.headline)

                    ForEach(viewModel.saliencyResults) { result in
                        SaliencyResultCard(result: result)
                    }

                    // Info about attention-based saliency
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Attention-Based Saliency")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model identifies regions that naturally draw human attention based on visual features like color, texture, and contrast. These are areas where viewers typically focus first when looking at an image.")
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

// MARK: - Saliency Result Card

/// Card displaying saliency analysis results
struct SaliencyResultCard: View {
    let result: AttentionSaliency

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
                    Text("\(result.salientObjects.count) Salient Region\(result.salientObjects.count == 1 ? "" : "s") Detected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(result.salientObjects) { object in
                        SalientObjectRow(object: object)
                    }
                }
            } else {
                Text("No discrete salient regions identified")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saliency map with confidence \(String(format: "%.0f%%", result.confidence * 100)), \(result.salientObjects.count) salient regions")
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

// MARK: - Salient Object Row

/// Row displaying a salient object
struct SalientObjectRow: View {
    let object: SalientObject

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Region \(object.index + 1)")
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
        GenerateAttentionBasedSaliencyImageView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .generateAttentionBasedSaliencyImage })!
        )
    }
}
