import SwiftUI

/// Detail view for the Detect Lens Smudge model
struct DetectLensSmudgeView: View {
    let model: VisionModel

    @State private var viewModel: DetectLensSmudgeViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectLensSmudgeViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            if let result = viewModel.smudgeResult {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Lens Smudge Detection")
                        .font(.headline)

                    // Detection Result Card
                    VStack(spacing: 16) {
                        // Circular progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 12)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: CGFloat(result.confidence))
                                .stroke(statusColor(result.confidence), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 4) {
                                Text(String(format: "%.1f%%", result.confidencePercentage))
                                    .font(.system(size: 32, weight: .bold))
                                Text("confidence")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(spacing: 8) {
                            Text(result.detectionStatus)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Detection Status")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Recommendation info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendation")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(result.recommendation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // About This Detection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About This Detection")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("This feature analyzes images to detect if the camera lens has smudges, fingerprints, or other obstructions that may affect image quality. Higher confidence scores indicate a greater likelihood of lens contamination.")
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

    private func statusColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .red
        case 0.5..<0.8:
            return .orange
        case 0.3..<0.5:
            return .yellow
        default:
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectLensSmudgeView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectLensSmudge })!
        )
    }
}
