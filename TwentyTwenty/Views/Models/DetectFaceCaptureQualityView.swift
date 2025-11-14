import SwiftUI

/// Detail view for the Detect Face Capture Quality model
struct DetectFaceCaptureQualityView: View {
    let model: VisionModel

    @State private var viewModel: DetectFaceCaptureQualityViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectFaceCaptureQualityViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.faceQualityResults.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Face Capture Quality Analysis")
                        .font(.headline)

                    Text("\(viewModel.faceQualityResults.count) face(s) analyzed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.faceQualityResults) { result in
                        FaceQualityCard(result: result)
                    }

                    // Info about quality score
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Quality Scores")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("The quality score indicates how suitable a face image is for facial recognition. Higher scores indicate better lighting, pose, and image clarity. Scores above 0.7 are excellent for recognition tasks.")
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

// MARK: - Face Quality Card

/// Card displaying face quality information
struct FaceQualityCard: View {
    let result: FaceQualityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Face \(result.index + 1)")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", result.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(result.confidence))
            }

            // Quality score with circular progress
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: CGFloat(result.quality))
                        .stroke(
                            qualityColor(result.quality),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f%%", result.quality * 100))
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(result.qualityRating)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Capture Quality")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Bounding box info
            VStack(alignment: .leading, spacing: 8) {
                Text("Bounding Box")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Position")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(result.boundingBox.origin.x)), \(Int(result.boundingBox.origin.y)))")
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Size")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(result.boundingBox.width)) × \(Int(result.boundingBox.height))")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Face \(result.index + 1), confidence \(String(format: "%.0f%%", result.confidence * 100)), quality \(String(format: "%.0f%%", result.quality * 100)), rating \(result.qualityRating)")
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

    private func qualityColor(_ quality: Float) -> Color {
        if quality > 0.7 {
            return .green
        } else if quality > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectFaceCaptureQualityView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectFaceCaptureQuality })!
        )
    }
}
