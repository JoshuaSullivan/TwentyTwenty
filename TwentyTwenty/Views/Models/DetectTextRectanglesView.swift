import SwiftUI

/// Detail view for the Detect Text Rectangles model
struct DetectTextRectanglesView: View {
    let model: VisionModel

    @State private var viewModel: DetectTextRectanglesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectTextRectanglesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.textRectangles.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Text Regions")
                        .font(.headline)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.viewfinder")
                                .foregroundStyle(.blue)
                            Text("\(viewModel.textRectangles.count) region(s)")
                                .font(.subheadline)
                        }

                        Divider()
                            .frame(height: 20)

                        HStack(spacing: 6) {
                            Image(systemName: "square.dashed")
                                .foregroundStyle(.green)
                            Text("Layout detection")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    ForEach(viewModel.textRectangles) { rectangle in
                        TextRectangleCard(rectangle: rectangle)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Text Rectangle Detection")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model quickly identifies regions containing text without performing OCR. It's useful for layout analysis and detecting where text appears in an image. For actual text recognition, use the Recognize Text model.")
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

// MARK: - Text Rectangle Card

/// Card displaying text rectangle information
struct TextRectangleCard: View {
    let rectangle: DetectedTextRectangle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.blue)
                    Text("Region \(rectangle.index + 1)")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", rectangle.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(rectangle.confidence))
            }

            // Rectangle details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Position")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(rectangle.boundingBox.origin.x)), \(Int(rectangle.boundingBox.origin.y)))")
                            .font(.body)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(rectangle.boundingBox.width)) × \(Int(rectangle.boundingBox.height))")
                            .font(.body)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Area")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(rectangle.area)) px²")
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Text region \(rectangle.index + 1), confidence \(String(format: "%.0f%%", rectangle.confidence * 100))")
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
        DetectTextRectanglesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectTextRectangles })!
        )
    }
}
