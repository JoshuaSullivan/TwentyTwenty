import SwiftUI

/// Detail view for the Detect Face Landmarks model
struct DetectFaceLandmarksView: View {
    let model: VisionModel

    @State private var viewModel: DetectFaceLandmarksViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectFaceLandmarksViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.detectedFaces.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Faces with Landmarks")
                        .font(.headline)

                    Text("\(viewModel.detectedFaces.count) face(s) found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.detectedFaces) { face in
                        FaceLandmarksCard(face: face)
                    }
                }
            }
        })
    }
}

// MARK: - Face Landmarks Card

/// Card displaying information about a detected face with landmarks
struct FaceLandmarksCard: View {
    let face: FaceWithLandmarks

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

            // Landmarks grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    landmarkBadge(name: "Left Eye", detected: face.landmarks.hasLeftEye)
                    landmarkBadge(name: "Right Eye", detected: face.landmarks.hasRightEye)
                    landmarkBadge(name: "Nose", detected: face.landmarks.hasNose)
                    landmarkBadge(name: "Mouth", detected: face.landmarks.hasMouth)
                    landmarkBadge(name: "Left Eyebrow", detected: face.landmarks.hasLeftEyebrow)
                    landmarkBadge(name: "Right Eyebrow", detected: face.landmarks.hasRightEyebrow)
                    landmarkBadge(name: "Face Contour", detected: face.landmarks.hasFaceContour)
                }
            }

            // Point count
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.blue)
                Text("\(face.landmarks.totalPointsCount) landmark points detected")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Face \(face.index + 1), confidence \(String(format: "%.0f%%", face.confidence * 100)), \(face.landmarks.totalPointsCount) landmarks")
    }

    private func landmarkBadge(name: String, detected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: detected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(detected ? .green : .secondary)

            Text(name)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
        DetectFaceLandmarksView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectFaceLandmarks })!
        )
    }
}
