import SwiftUI
import AVFoundation
import Vision

/// Video player with synchronized rectangle tracking overlay visualization
struct RectangleTrackingVideoPlayerView: View {
    let videoAsset: AVAsset
    let trackResults: [RectangleTrackResult]
    let totalFrames: Int

    @StateObject private var videoSync = VideoSyncCoordinator()
    @State private var duration: Double = 0
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 16) {
            // Video player with overlay
            GeometryReader { geometry in
                ZStack {
                    // Video player
                    if let player = videoSync.player {
                        VideoPlayer(player: player)
                            .disabled(true)
                    }

                    // Rectangle tracking overlay
                    RectangleTrackingOverlayView(
                        currentTime: videoSync.currentTime,
                        duration: duration,
                        trackResults: trackResults,
                        totalFrames: totalFrames,
                        containerSize: geometry.size
                    )
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Playback info
            HStack {
                let frameInfo = currentFrameInfo()

                if let info = frameInfo, info.wasTracked {
                    Image(systemName: "scope")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                Text(formatTime(videoSync.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text("/")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if let info = frameInfo, !info.wasTracked {
                    Text("• Tracking Lost")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                if let info = frameInfo, info.wasTracked {
                    Text(String(format: "%.0f%%", info.confidence * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(confidenceColor(info.confidence))
                }
            }

            // Timeline scrubber
            Slider(
                value: Binding(
                    get: { videoSync.currentTime },
                    set: { newTime in
                        videoSync.player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                    }
                ),
                in: 0...max(duration, 0.1)
            )

            // Playback controls
            HStack(spacing: 24) {
                // Rewind
                Button {
                    videoSync.player?.seek(to: .zero)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }

                // Play/Pause
                Button {
                    if isPlaying {
                        videoSync.player?.pause()
                    } else {
                        videoSync.player?.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }

                Spacer()
            }
            .tint(.blue)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            videoSync.cleanup()
        }
    }

    // MARK: - Helper Methods

    private func setupPlayer() {
        videoSync.setup(with: videoAsset)

        // Get duration
        Task {
            if let duration = try? await videoAsset.load(.duration) {
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(duration)
                }
            }
        }

        // Observe playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoSync.playerItem,
            queue: .main
        ) { [weak videoSync] _ in
            isPlaying = false
            Task { @MainActor in
                videoSync?.player?.seek(to: .zero)
            }
        }
    }

    private func currentFrameInfo() -> RectangleTrackResult? {
        guard duration > 0 else { return nil }

        let progress = videoSync.currentTime / duration
        let frameIndex = Int(progress * Double(totalFrames))

        return trackResults.first(where: { $0.frameIndex == frameIndex })
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, millis)
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

// MARK: - Rectangle Tracking Overlay View

struct RectangleTrackingOverlayView: View {
    let currentTime: Double
    let duration: Double
    let trackResults: [RectangleTrackResult]
    let totalFrames: Int
    let containerSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let result = interpolatedRectangle() {
                let corners = convertToViewCoordinates(result, in: geometry.size)

                // Draw quadrilateral
                Path { path in
                    path.move(to: corners.topLeft)
                    path.addLine(to: corners.topRight)
                    path.addLine(to: corners.bottomRight)
                    path.addLine(to: corners.bottomLeft)
                    path.closeSubpath()
                }
                .stroke(confidenceColor(result.confidence), lineWidth: 3)

                // Draw corner points
                ForEach([corners.topLeft, corners.topRight, corners.bottomRight, corners.bottomLeft], id: \.debugDescription) { corner in
                    Circle()
                        .fill(confidenceColor(result.confidence))
                        .frame(width: 12, height: 12)
                        .position(corner)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 12, height: 12)
                                .position(corner)
                        )
                }

                // Confidence label
                Text(String(format: "%.0f%%", result.confidence * 100))
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor(result.confidence))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: corners.topLeft.x + 30, y: corners.topLeft.y - 12)
            }
        }
    }

    // MARK: - Interpolation

    private func interpolatedRectangle() -> RectangleTrackResult? {
        guard duration > 0, !trackResults.isEmpty else { return nil }

        let progress = currentTime / duration
        let framePosition = progress * Double(totalFrames - 1)
        let frameIndex = Int(framePosition)

        // Find the current frame result
        guard let currentResult = trackResults.first(where: { $0.frameIndex == frameIndex }),
              currentResult.wasTracked else {
            return nil
        }

        return currentResult
    }

    private func convertToViewCoordinates(
        _ result: RectangleTrackResult,
        in size: CGSize
    ) -> (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        // NormalizedPoint uses bottom-left origin, SwiftUI uses top-left
        return (
            topLeft: CGPoint(
                x: result.topLeft.x * size.width,
                y: (1.0 - result.topLeft.y) * size.height
            ),
            topRight: CGPoint(
                x: result.topRight.x * size.width,
                y: (1.0 - result.topRight.y) * size.height
            ),
            bottomRight: CGPoint(
                x: result.bottomRight.x * size.width,
                y: (1.0 - result.bottomRight.y) * size.height
            ),
            bottomLeft: CGPoint(
                x: result.bottomLeft.x * size.width,
                y: (1.0 - result.bottomLeft.y) * size.height
            )
        )
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
