import SwiftUI

/// Detail view for the Classify Image model
struct ClassifyImageView: View {
    let model: VisionModel

    @State private var viewModel: ClassifyImageViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: ClassifyImageViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            // Configuration View
            VStack(alignment: .leading, spacing: 12) {
                Text("Maximum Results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Stepper("\(viewModel.maxResults) results", value: $viewModel.maxResults, in: 1...50)
                    .accessibilityLabel("Maximum number of classification results: \(viewModel.maxResults)")
            }
        }, resultsView: {
            // Results View
            if !viewModel.classifications.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Classifications")
                        .font(.headline)

                    Text("Top \(viewModel.classifications.count) results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(Array(viewModel.classifications.enumerated()), id: \.element.id) { index, classification in
                        ClassificationCard(classification: classification, rank: index + 1)
                    }
                }
            }
        })
    }
}

// MARK: - Classification Card

/// Card displaying a single classification result
struct ClassificationCard: View {
    let classification: ImageClassification
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(rankColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(classification.identifier.capitalized)
                    .font(.body)

                ProgressView(value: Double(classification.confidence))
                    .tint(confidenceColor(classification.confidence))
            }

            Spacer()

            Text(String(format: "%.1f%%", classification.confidence * 100))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank): \(classification.identifier), confidence \(String(format: "%.1f%%", classification.confidence * 100))")
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .green
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.7 {
            return .green
        } else if confidence > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClassifyImageView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .classifyImage })!
        )
    }
}
