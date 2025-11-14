import SwiftUI

/// Detail view for the Detect Face Rectangles model
struct DetectFaceRectanglesView: View {
    let model: VisionModel

    @State private var viewModel: DetectFaceRectanglesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectFaceRectanglesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel) {
            // Results View
            if !viewModel.detectedFaces.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Faces")
                        .font(.headline)

                    Text("\(viewModel.detectedFaces.count) face(s) found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedFaces) { face in
                        FaceCard(face: face)
                    }
                }
            }
        }
    }
}

// MARK: - Face Card

/// Card displaying information about a detected face
struct FaceCard: View {
    let face: DetectedFace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Face \(face.index + 1)")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", face.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(face.confidence))
            }

            HStack(spacing: 16) {
                InfoLabel(icon: "arrow.left.and.right", text: String(format: "%.0f px", face.boundingBox.width))
                InfoLabel(icon: "arrow.up.and.down", text: String(format: "%.0f px", face.boundingBox.height))
                InfoLabel(icon: "location", text: String(format: "(%.0f, %.0f)", face.boundingBox.origin.x, face.boundingBox.origin.y))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Face \(face.index + 1), confidence \(String(format: "%.0f%%", face.confidence * 100))")
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
        DetectFaceRectanglesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectFaceRectangles })!
        )
    }
}
