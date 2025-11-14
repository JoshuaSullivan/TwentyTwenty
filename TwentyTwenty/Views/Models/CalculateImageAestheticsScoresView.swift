import SwiftUI

/// Detail view for the Calculate Image Aesthetics Scores model
struct CalculateImageAestheticsScoresView: View {
    let model: VisionModel

    @State private var viewModel: CalculateImageAestheticsScoresViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: CalculateImageAestheticsScoresViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if let scores = viewModel.aestheticsScores {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Aesthetics Analysis")
                        .font(.headline)

                    // Overall Score Card
                    VStack(spacing: 16) {
                        // Circular progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 12)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: CGFloat(scores.overallScore))
                                .stroke(scoreColor(scores.overallScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", scores.overallScorePercentage))
                                    .font(.system(size: 32, weight: .bold))
                                Text("out of 100")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(spacing: 8) {
                            Text(scores.qualityRating)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Overall Aesthetic Quality")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Score breakdown info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About This Score")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("The aesthetics score evaluates the overall visual appeal of the image, considering factors like composition, lighting, subject matter, and technical quality.")
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

    private func scoreColor(_ score: Float) -> Color {
        switch score {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .blue
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CalculateImageAestheticsScoresView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .calculateImageAestheticsScores })!
        )
    }
}
