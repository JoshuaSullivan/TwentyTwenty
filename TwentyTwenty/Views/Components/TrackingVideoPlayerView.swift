import SwiftUI
import AVFoundation
import Vision
import Combine

/// Video player with synchronized tracking overlay visualization
struct TrackingVideoPlayerView: View {
    let videoAsset: AVAsset
    let trackResults: [TrackResult]
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
                            .disabled(true) // Disable native controls
                    }

                    // Tracking overlay
                    TrackingOverlayView(
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

    private func currentFrameInfo() -> TrackResult? {
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

// MARK: - Video Sync Coordinator

/// Coordinates video playback with frame-accurate time updates using AVPlayerItemVideoOutput
@MainActor
class VideoSyncCoordinator: NSObject, ObservableObject {
    @Published var currentTime: Double = 0

    private(set) var player: AVPlayer?
    private(set) var playerItem: AVPlayerItem?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?

    func setup(with asset: AVAsset) {
        // Create video output with pixel format
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)

        // Create player item and add video output
        let item = AVPlayerItem(asset: asset)
        if let output = videoOutput {
            item.add(output)
        }
        playerItem = item

        // Create player
        player = AVPlayer(playerItem: item)

        // Set up display link for frame callbacks
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkCallback() {
        guard let output = videoOutput,
              let item = playerItem else {
            return
        }

        // Get the current time from the player
        let itemTime = item.currentTime()

        // Check if there's a new pixel buffer available
        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            // Update current time
            currentTime = CMTimeGetSeconds(itemTime)
        }
    }

    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        player?.pause()
        player = nil
        playerItem = nil
        videoOutput = nil
    }
}

// MARK: - Tracking Overlay View

struct TrackingOverlayView: View {
    let currentTime: Double
    let duration: Double
    let trackResults: [TrackResult]
    let totalFrames: Int
    let containerSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let (boundingBox, confidence) = interpolatedBoundingBox() {
                let rect = convertToViewCoordinates(boundingBox, in: geometry.size)

                Rectangle()
                    .stroke(confidenceColor(confidence), lineWidth: 3)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Confidence label
                Text(String(format: "%.0f%%", confidence * 100))
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor(confidence))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: rect.minX + 30, y: rect.minY - 12)
            }
        }
    }

    // MARK: - Interpolation

    private func interpolatedBoundingBox() -> (boundingBox: NormalizedRect, confidence: Float)? {
        guard duration > 0, !trackResults.isEmpty else { return nil }

        let progress = currentTime / duration
        let framePosition = progress * Double(totalFrames - 1)
        let frameIndex = Int(framePosition)

        // Find the surrounding detection frames
        let currentResult = trackResults.first(where: { $0.frameIndex == frameIndex })
        let nextResult = trackResults.first(where: { $0.frameIndex == frameIndex + 1 })

        guard let current = currentResult, current.wasTracked else {
            return nil
        }

        // If we don't have a next frame or it wasn't tracked, use current frame
        guard let next = nextResult, next.wasTracked else {
            return (current.boundingBox, current.confidence)
        }

        // Interpolate between current and next frame
        let t = CGFloat(framePosition - Double(frameIndex))

        let interpolatedX = current.boundingBox.origin.x + (next.boundingBox.origin.x - current.boundingBox.origin.x) * t
        let interpolatedY = current.boundingBox.origin.y + (next.boundingBox.origin.y - current.boundingBox.origin.y) * t
        let interpolatedWidth = current.boundingBox.width + (next.boundingBox.width - current.boundingBox.width) * t
        let interpolatedHeight = current.boundingBox.height + (next.boundingBox.height - current.boundingBox.height) * t

        let interpolatedBox = NormalizedRect(
            x: interpolatedX,
            y: interpolatedY,
            width: interpolatedWidth,
            height: interpolatedHeight
        )

        let interpolatedConfidence = current.confidence + (next.confidence - current.confidence) * Float(t)

        return (interpolatedBox, interpolatedConfidence)
    }

    private func convertToViewCoordinates(_ box: NormalizedRect, in size: CGSize) -> CGRect {
        // NormalizedRect uses bottom-left origin, SwiftUI uses top-left
        return CGRect(
            x: box.origin.x * size.width,
            y: (1.0 - box.origin.y - box.height) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
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

// MARK: - Simple Video Player Wrapper

struct VideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        // Player is already set, no updates needed
        // The layer frame will be updated automatically in layoutSubviews
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
    }

    // Custom UIView that properly manages the AVPlayerLayer
    class PlayerView: UIView {
        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
    }
}
