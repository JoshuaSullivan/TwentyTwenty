import SwiftUI

/// Detail view for the Track Rectangle model
struct TrackRectangleView: View {
    let model: VisionModel

    @State private var viewModel: TrackRectangleViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackRectangleViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(
            viewModel: viewModel,
            resultsView: {
                if !viewModel.detectedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Rectangle Tracking Results")
                            .font(.headline)

                        ForEach(viewModel.detectedTracks) { track in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "rectangle.dashed")
                                        .foregroundStyle(.blue)
                                    Text("Tracked Rectangle")
                                        .font(.headline)

                                    Spacer()

                                    Label(
                                        String(format: "%.0f%%", track.successRate),
                                        systemImage: "checkmark.circle.fill"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(track.successRate > 80 ? .green : track.successRate > 50 ? .orange : .red)
                                }

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Frames Tracked")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(track.successfulFrames) / \(track.totalFrames)")
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }

                                    Divider()
                                        .frame(height: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Avg. Confidence")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(String(format: "%.1f%%", track.averageConfidence * 100))
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

                        Text("Note: Full rectangle visualization coming soon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackRectangleView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackRectangle })!
        )
    }
}
