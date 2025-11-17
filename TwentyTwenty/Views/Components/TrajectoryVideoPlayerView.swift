import SwiftUI
import AVFoundation
import Vision

/// Video player with synchronized trajectory path overlay visualization
struct TrajectoryVideoPlayerView: View {
    let videoAsset: AVAsset
    let trajectories: [TrajectoryObservation]
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

                    // Trajectory overlay
                    TrajectoryOverlayView(
                        currentTime: videoSync.currentTime,
                        duration: duration,
                        trajectories: trajectories,
                        containerSize: geometry.size
                    )
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Playback info
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
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

                Text("\(trajectories.count) trajectories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, millis)
    }
}

// MARK: - Trajectory Overlay View

struct TrajectoryOverlayView: View {
    let currentTime: Double
    let duration: Double
    let trajectories: [TrajectoryObservation]
    let containerSize: CGSize

    // Different colors for different trajectories
    private let trajectoryColors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(trajectories.enumerated()), id: \.offset) { index, trajectory in
                let color = trajectoryColors[index % trajectoryColors.count]

                // Draw detected points
                ForEach(Array(trajectory.detectedPoints.enumerated()), id: \.offset) { pointIndex, point in
                    let viewPoint = convertToViewCoordinates(point, in: geometry.size)
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(viewPoint)
                }

                // Draw detected path
                Path { path in
                    for (pointIndex, point) in trajectory.detectedPoints.enumerated() {
                        let viewPoint = convertToViewCoordinates(point, in: geometry.size)
                        if pointIndex == 0 {
                            path.move(to: viewPoint)
                        } else {
                            path.addLine(to: viewPoint)
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Draw projected points with dashed line
                if !trajectory.projectedPoints.isEmpty {
                    Path { path in
                        // Connect last detected point to first projected point
                        if let lastDetected = trajectory.detectedPoints.last {
                            let lastViewPoint = convertToViewCoordinates(lastDetected, in: geometry.size)
                            path.move(to: lastViewPoint)

                            for point in trajectory.projectedPoints {
                                let viewPoint = convertToViewCoordinates(point, in: geometry.size)
                                path.addLine(to: viewPoint)
                            }
                        }
                    }
                    .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))

                    // Draw projected points
                    ForEach(Array(trajectory.projectedPoints.enumerated()), id: \.offset) { pointIndex, point in
                        let viewPoint = convertToViewCoordinates(point, in: geometry.size)
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 2)
                            .frame(width: 6, height: 6)
                            .position(viewPoint)
                    }
                }

                // Confidence label for this trajectory
                if let firstPoint = trajectory.detectedPoints.first {
                    let viewPoint = convertToViewCoordinates(firstPoint, in: geometry.size)
                    Text(String(format: "%.0f%%", trajectory.confidence * 100))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .position(x: viewPoint.x, y: viewPoint.y - 15)
                }
            }
        }
    }

    private func convertToViewCoordinates(_ point: NormalizedPoint, in size: CGSize) -> CGPoint {
        // NormalizedPoint uses bottom-left origin, SwiftUI uses top-left
        return CGPoint(
            x: point.x * size.width,
            y: (1.0 - point.y) * size.height
        )
    }
}
