import SwiftUI

/// Detail view for the Detect Document Segmentation model
struct DetectDocumentSegmentationView: View {
    let model: VisionModel

    @State private var viewModel: DetectDocumentSegmentationViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectDocumentSegmentationViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.detectedDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Documents")
                        .font(.headline)

                    Text("\(viewModel.detectedDocuments.count) document(s) found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedDocuments) { document in
                        DocumentCard(document: document)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Document Segmentation")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model identifies document boundaries in images, making it useful for scanning documents with cameras. It can detect documents even when photographed at an angle, providing corner points that can be used for perspective correction.")
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

// MARK: - Document Card

/// Card displaying document information
struct DocumentCard: View {
    let document: DetectedDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(.blue)
                    Text("Document \(document.index + 1)")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", document.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(document.confidence))
            }

            // Document details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Position")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(document.boundingBox.origin.x)), \(Int(document.boundingBox.origin.y)))")
                            .font(.body)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(document.boundingBox.width)) × \(Int(document.boundingBox.height))")
                            .font(.body)
                    }
                }

                Divider()

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Area")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(document.area)) px²")
                            .font(.body)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aspect Ratio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", document.aspectRatio))
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
        .accessibilityLabel("Document \(document.index + 1), confidence \(String(format: "%.0f%%", document.confidence * 100))")
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
        DetectDocumentSegmentationView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectDocumentSegmentation })!
        )
    }
}
