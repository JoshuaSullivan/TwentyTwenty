import SwiftUI
import Vision

/// Detail view for the Track Object model
struct TrackObjectView: View {
    let model: VisionModel

    @State private var viewModel: TrackObjectViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: TrackObjectViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(
            viewModel: viewModel,
            configurationView: {
                // Configuration: Object Selection
                if let firstFrame = viewModel.firstFrame {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.selectedBoundingBox == nil {
                            ObjectSelectionView(firstFrame: firstFrame) { rect in
                                viewModel.selectedBoundingBox = rect
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Object selected and ready to track")
                                    .font(.subheadline)

                                Spacer()

                                Button("Change Selection") {
                                    viewModel.selectedBoundingBox = nil
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            },
            resultsView: {
                // Results View
                if !viewModel.detectedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Object Tracking Results")
                            .font(.headline)

                        // Video playback with tracking overlay
                        if let video = viewModel.selectedVideo,
                           let track = viewModel.detectedTracks.first {
                            TrackingVideoPlayerView(
                                videoAsset: video,
                                trackResults: track.results,
                                totalFrames: track.totalFrames
                            )
                        }

                        ForEach(viewModel.detectedTracks) { track in
                            ObjectTrackCard(track: track)
                        }

                        // Debug: Frame-by-frame tracking results
                        if let track = viewModel.detectedTracks.first {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Debug: Frame-by-Frame Results")
                                    .font(.headline)

                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 8) {
                                        ForEach(track.results) { result in
                                            FrameResultRow(result: result)
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Object Tracking")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("Object tracking follows the position of objects across video frames. You selected an object in the first frame, and the tracker followed its movement through \(viewModel.detectedTracks.first?.totalFrames ?? 0) frames. Success rate indicates what percentage of frames maintained tracking.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        )
        .onChange(of: viewModel.selectedVideo) { _, newValue in
            if newValue != nil {
                Task {
                    await viewModel.loadFirstFrame()
                }
            }
        }
    }
}

// MARK: - Object Track Card

/// Card displaying object tracking information
struct ObjectTrackCard: View {
    let track: ObjectTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .foregroundStyle(.blue)
                    Text("Tracked Object")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.0f%%", track.successRate),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(successRateColor(track.successRate))
            }

            // Track statistics
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frames Tracked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "film")
                                .foregroundStyle(.blue)
                            Text("\(track.successfulFrames) / \(track.totalFrames)")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg. Confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.green)
                            Text(String(format: "%.1f%%", track.averageConfidence * 100))
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                }

                Divider()

                Text("Object was successfully tracked through \(track.successfulFrames) frames with \(String(format: "%.0f%%", track.successRate)) success rate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tracked object with \(String(format: "%.0f%%", track.successRate)) success rate")
    }

    private func successRateColor(_ rate: Double) -> Color {
        if rate > 80 {
            return .green
        } else if rate > 50 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Frame Result Row

/// Debug view showing individual frame tracking result
struct FrameResultRow: View {
    let result: TrackResult

    var body: some View {
        HStack(spacing: 12) {
            // Frame number
            Text("Frame \(result.frameIndex)")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 70, alignment: .leading)

            // Status indicator
            if result.wasTracked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Bounding box
            VStack(alignment: .leading, spacing: 2) {
                Text("Box: (\(String(format: "%.3f", result.boundingBox.origin.x)), \(String(format: "%.3f", result.boundingBox.origin.y)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Size: \(String(format: "%.3f", result.boundingBox.width)) × \(String(format: "%.3f", result.boundingBox.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Confidence
            if result.wasTracked {
                Text(String(format: "%.1f%%", result.confidence * 100))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(confidenceColor(result.confidence))
            } else {
                Text("Lost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(result.wasTracked ? Color(.systemGray6).opacity(0.5) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.8 {
            return .green
        } else if confidence > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Video Requirement Notice

/// Reusable component for models requiring video input
struct VideoRequirementNotice: View {
    let title: String
    let description: String
    let capabilities: [String]
    let workflow: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Capabilities
            VStack(alignment: .leading, spacing: 12) {
                Text("Capabilities")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(capabilities, id: \.self) { capability in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .frame(width: 16)

                            Text(capability)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Workflow
            VStack(alignment: .leading, spacing: 12) {
                Text("Typical Workflow")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(workflow.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .frame(width: 24, alignment: .trailing)

                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Video requirement notice
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("This model requires video input and cannot be demonstrated with static images.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackObjectView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .trackObject })!
        )
    }
}
