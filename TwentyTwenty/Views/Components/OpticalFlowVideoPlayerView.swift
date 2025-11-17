import SwiftUI
import AVFoundation
import Vision

/// Video player with sparse optical flow vector field visualization
struct OpticalFlowVideoPlayerView: View {
    let videoAsset: AVAsset
    let flowResults: [OpticalFlowResult]
    let totalFrames: Int

    @StateObject private var videoSync = VideoSyncCoordinator()
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var vectorSpacing: Double = 20 // pixels between sampled vectors

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

                    // Optical flow overlay
                    OpticalFlowOverlayView(
                        currentTime: videoSync.currentTime,
                        duration: duration,
                        flowResults: flowResults,
                        totalFrames: totalFrames,
                        containerSize: geometry.size,
                        vectorSpacing: vectorSpacing
                    )
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Playback info
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.blue)

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

                Spacer()

                let frameInfo = currentFrameInfo()
                if let info = frameInfo, info.wasSuccessful {
                    Text(String(format: "%.0f%%", info.confidence * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(info.confidence > 0.8 ? .green : info.confidence > 0.5 ? .orange : .red)
                }
            }

            // Vector spacing control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Vector Spacing:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(vectorSpacing))px")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Slider(value: $vectorSpacing, in: 10...50, step: 5)
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
        ) { _ in
            Task { @MainActor [weak videoSync] in
                isPlaying = false
                videoSync?.player?.seek(to: .zero)
            }
        }
    }

    private func currentFrameInfo() -> OpticalFlowResult? {
        guard duration > 0 else { return nil }

        let progress = videoSync.currentTime / duration
        let frameIndex = Int(progress * Double(totalFrames))

        return flowResults.first(where: { $0.framePairIndex == frameIndex })
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, millis)
    }
}

// MARK: - Optical Flow Overlay View

struct OpticalFlowOverlayView: View {
    let currentTime: Double
    let duration: Double
    let flowResults: [OpticalFlowResult]
    let totalFrames: Int
    let containerSize: CGSize
    let vectorSpacing: Double

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("⚠️ Partial Visualization")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(radius: 2)

                Text("Optical flow generates dense motion vectors. Full vector field rendering requires pixel buffer access and would be implemented for production use.")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal)
            }
            .position(x: geometry.size.width / 2, y: 40)
        }
    }
}
