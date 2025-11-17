import SwiftUI

/// Detail view for the Track Optical Flow model
struct TrackOpticalFlowView: View {
    let model: VisionModel

    @State private var viewModel: TrackOpticalFlowViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackOpticalFlowViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(
            viewModel: viewModel,
            resultsView: {
                if !viewModel.opticalFlowResults.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Optical Flow Results")
                            .font(.headline)

                        Text("Processed \(viewModel.opticalFlowResults.count) frame pair(s)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Video playback with optical flow overlay
                        if let video = viewModel.selectedVideo {
                            OpticalFlowVideoPlayerView(
                                videoAsset: video,
                                flowResults: viewModel.opticalFlowResults,
                                totalFrames: 30
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundStyle(.blue)
                                Text("Flow Analysis")
                                    .font(.headline)

                                Spacer()

                                let avgConfidence = viewModel.opticalFlowResults.reduce(0) { $0 + $1.confidence } / Float(viewModel.opticalFlowResults.count)
                                Text(String(format: "%.0f%%", avgConfidence * 100))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(avgConfidence > 0.8 ? .green : avgConfidence > 0.5 ? .orange : .red)
                            }

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Frame Pairs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(viewModel.opticalFlowResults.count)")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }

                                Divider()
                                    .frame(height: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Successful")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    let successful = viewModel.opticalFlowResults.filter { $0.wasSuccessful }.count
                                    Text("\(successful)")
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackOpticalFlowView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackOpticalFlow })!
        )
    }
}
