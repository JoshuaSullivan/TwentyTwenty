import SwiftUI

/// Detail view for the Detect Contours model
struct DetectContoursView: View {
    let model: VisionModel

    @State private var viewModel: DetectContoursViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectContoursViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            // Configuration View
            VStack(alignment: .leading, spacing: 12) {
                Text("Contrast Threshold")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: Binding(
                        get: { Double(viewModel.contrastThreshold) },
                        set: { viewModel.contrastThreshold = Float($0) }
                    ), in: 0.0...1.0)

                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "%.2f", viewModel.contrastThreshold))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Higher values detect more prominent edges")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }, resultsView: {
            // Results View
            if !viewModel.detectedContours.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Contours")
                        .font(.headline)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "scribble.variable")
                                .foregroundStyle(.blue)
                            Text("\(viewModel.detectedContours.count) contour(s)")
                                .font(.subheadline)
                        }

                        Divider()
                            .frame(height: 20)

                        HStack(spacing: 6) {
                            Image(systemName: "circle.dotted")
                                .foregroundStyle(.green)
                            let totalPoints = viewModel.detectedContours.reduce(0) { $0 + $1.pointCount }
                            Text("\(totalPoints) total points")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    ForEach(viewModel.detectedContours) { contour in
                        ContourCard(contour: contour)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Contour Detection")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model finds edges and contours in images by detecting areas of high contrast. Contours can be used for shape analysis, object recognition, and image segmentation. Adjust the contrast threshold to control sensitivity.")
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

// MARK: - Contour Card

/// Card displaying contour information
struct ContourCard: View {
    let contour: DetectedContour

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "lasso")
                        .foregroundStyle(.blue)
                    Text("Contour \(contour.index + 1)")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", contour.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(contour.confidence))
            }

            // Contour details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Points")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(contour.pointCount)")
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Child Contours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(contour.childContourCount)")
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aspect Ratio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", contour.aspectRatio))
                            .font(.body)
                            .fontWeight(.medium)
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
        .accessibilityLabel("Contour \(contour.index + 1), \(contour.pointCount) points")
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
        DetectContoursView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectContours })!
        )
    }
}
