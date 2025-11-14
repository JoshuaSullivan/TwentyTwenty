import SwiftUI

/// Detail view for the Detect Rectangles model
struct DetectRectanglesView: View {
    let model: VisionModel

    @State private var viewModel: DetectRectanglesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectRectanglesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            // Configuration View
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Aspect Ratio: \(String(format: "%.2f", viewModel.minimumAspectRatio))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Slider(value: $viewModel.minimumAspectRatio, in: 0...1)
                        .accessibilityLabel("Minimum aspect ratio for detected rectangles")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Maximum Aspect Ratio: \(String(format: "%.2f", viewModel.maximumAspectRatio))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Slider(value: $viewModel.maximumAspectRatio, in: 0...1)
                        .accessibilityLabel("Maximum aspect ratio for detected rectangles")
                }
            }
        }, resultsView: {
            // Results View
            if !viewModel.detectedRectangles.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Rectangles")
                        .font(.headline)

                    Text("\(viewModel.detectedRectangles.count) rectangle(s) found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedRectangles) { rectangle in
                        RectangleCard(rectangle: rectangle)
                    }
                }
            }
        })
    }
}

// MARK: - Rectangle Card

/// Card displaying information about a detected rectangle
struct RectangleCard: View {
    let rectangle: DetectedRectangle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rectangle \(rectangle.index + 1)")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", rectangle.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(rectangle.confidence))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Dimensions & Aspect Ratio")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    InfoLabel(icon: "arrow.left.and.right", text: String(format: "%.0f px", rectangle.boundingBox.width))
                    InfoLabel(icon: "arrow.up.and.down", text: String(format: "%.0f px", rectangle.boundingBox.height))
                    InfoLabel(icon: "aspectratio", text: String(format: "%.2f", rectangle.aspectRatio))
                }
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Corner Points")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    cornerPoint(label: "TL", point: rectangle.topLeft)
                    cornerPoint(label: "TR", point: rectangle.topRight)
                    cornerPoint(label: "BL", point: rectangle.bottomLeft)
                    cornerPoint(label: "BR", point: rectangle.bottomRight)
                }
                .font(.caption2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rectangle \(rectangle.index + 1), confidence \(String(format: "%.0f%%", rectangle.confidence * 100)), aspect ratio \(String(format: "%.2f", rectangle.aspectRatio))")
    }

    private func cornerPoint(label: String, point: CGPoint) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
            Text("(\(Int(point.x)), \(Int(point.y)))")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
        DetectRectanglesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectRectangles })!
        )
    }
}
