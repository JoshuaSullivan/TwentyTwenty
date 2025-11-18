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
    @State private var scrubbingTime: Double? // Track time while scrubbing

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
                        currentTime: scrubbingTime ?? videoSync.currentTime,
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

                Text(formatTime(scrubbingTime ?? videoSync.currentTime))
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

                let frameInfo = currentFrameInfo(time: scrubbingTime ?? videoSync.currentTime)
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
                    get: { scrubbingTime ?? videoSync.currentTime },
                    set: { newTime in
                        scrubbingTime = newTime
                    }
                ),
                in: 0...max(duration, 0.1),
                onEditingChanged: { editing in
                    if !editing, let seekTime = scrubbingTime {
                        // User finished scrubbing, seek to the time
                        videoSync.player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                        scrubbingTime = nil
                    }
                }
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

    private func currentFrameInfo(time: Double) -> OpticalFlowResult? {
        guard duration > 0 else { return nil }

        let progress = time / duration
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
        Canvas { context, size in
            guard let currentObservation = getCurrentObservation() else { return }

            // Get the flow field size to understand coordinate space
            let flowSize = currentObservation.observation.size

            // Calculate scale factor from flow coordinates to view coordinates
            let scaleX = size.width / flowSize.width
            let scaleY = size.height / flowSize.height

            // Visualization scale - controls how much to amplify the vectors for visibility
            let visualScale = 15.0

            // Sample the flow field at regular intervals
            let spacing = vectorSpacing
            let cols = Int(size.width / spacing)
            let rows = Int(size.height / spacing)

            for row in 0..<rows {
                for col in 0..<cols {
                    // Calculate normalized point (0-1 range)
                    let normalizedX = Double(col) / Double(cols)
                    let normalizedY = Double(row) / Double(rows)
                    let point = NormalizedPoint(x: normalizedX, y: normalizedY)

                    // Get flow vector at this point (in flow field pixel coordinates)
                    let (dx, dy) = currentObservation.observation.flow(at: point)

                    // Skip very small vectors
                    let magnitude = sqrt(dx * dx + dy * dy)
                    guard magnitude > 0.1 else { continue }

                    // Calculate arrow position in view coordinates
                    let startX = Double(col) * spacing + spacing / 2
                    let startY = Double(row) * spacing + spacing / 2

                    // Scale flow vector to view coordinates and apply visualization scale
                    let scaledDx = Double(dx) * scaleX * visualScale
                    let scaledDy = Double(dy) * scaleY * visualScale

                    // Clamp arrow length to prevent going off screen
                    let maxArrowLength = spacing * 1.5
                    let scaledMagnitude = sqrt(scaledDx * scaledDx + scaledDy * scaledDy)
                    let clampedScale = min(1.0, maxArrowLength / scaledMagnitude)

                    let endX = startX + scaledDx * clampedScale
                    let endY = startY + scaledDy * clampedScale

                    // Draw arrow
                    let start = CGPoint(x: startX, y: startY)
                    let end = CGPoint(x: endX, y: endY)

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)

                    // Color based on magnitude
                    let color = colorForMagnitude(magnitude)
                    context.stroke(path, with: .color(color), lineWidth: 2)

                    // Draw arrowhead
                    drawArrowhead(context: context, from: start, to: end, color: color)
                }
            }
        }
    }

    private func getCurrentObservation() -> OpticalFlowResult? {
        guard duration > 0 else { return nil }

        let progress = currentTime / duration
        let frameIndex = Int(progress * Double(totalFrames))

        return flowResults.first(where: { $0.framePairIndex == frameIndex })
    }

    private func colorForMagnitude(_ magnitude: Float) -> Color {
        // Map magnitude to color (blue for slow, red for fast)
        let normalized = min(magnitude * 2.0, 1.0)
        return Color(
            red: Double(normalized),
            green: 0.3,
            blue: Double(1.0 - normalized)
        ).opacity(0.8)
    }

    private func drawArrowhead(context: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 8
        let arrowAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        var path = Path()
        path.move(to: end)
        path.addLine(to: point1)
        path.move(to: end)
        path.addLine(to: point2)

        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}
