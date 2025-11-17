import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics

/// Manages video resources and frame extraction for tracking models
enum VideoManager {
    // MARK: - Video Loading

    /// Load a bundled video asset
    /// - Parameter video: BundledVideo to load
    /// - Returns: AVAsset if the video exists, nil otherwise
    static func loadBundledVideo(_ video: BundledVideo) -> AVAsset? {
        guard let url = Bundle.main.url(forResource: video.id, withExtension: "mp4") else {
            return nil
        }
        return AVURLAsset(url: url)
    }

    /// Check if a bundled video exists
    /// - Parameter video: BundledVideo to check
    /// - Returns: True if the video file exists
    static func videoExists(_ video: BundledVideo) -> Bool {
        return Bundle.main.url(forResource: video.id, withExtension: "mp4") != nil
    }

    /// Get all available bundled videos
    /// - Returns: Array of bundled videos that exist in the bundle
    static func availableVideos() -> [BundledVideo] {
        return BundledVideoRegistry.allVideos.filter { videoExists($0) }
    }

    // MARK: - Frame Extraction

    /// Extract frames from a video at regular intervals
    /// - Parameters:
    ///   - asset: The video asset to extract frames from
    ///   - frameCount: Number of frames to extract
    /// - Returns: Array of CGImage frames
    static func extractFrames(from asset: AVAsset, frameCount: Int) async throws -> [CGImage] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        generator.appliesPreferredTrackTransform = true

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else {
            throw VideoError.invalidDuration
        }

        var frames: [CGImage] = []

        // Calculate time interval between frames
        let timeIncrement = durationSeconds / Double(frameCount)

        for i in 0..<frameCount {
            let timeSeconds = timeIncrement * Double(i)
            let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                frames.append(cgImage)
            } catch {
                // If we can't extract a specific frame, skip it but continue
                print("Warning: Failed to extract frame at time \(timeSeconds): \(error)")
            }
        }

        guard !frames.isEmpty else {
            throw VideoError.noFramesExtracted
        }

        return frames
    }

    /// Extract a single frame from a video at a specific time
    /// - Parameters:
    ///   - asset: The video asset to extract a frame from
    ///   - time: The time at which to extract the frame
    /// - Returns: CGImage at the specified time
    static func extractFrame(from asset: AVAsset, at time: CMTime) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        generator.appliesPreferredTrackTransform = true

        let (cgImage, _) = try await generator.image(at: time)
        return cgImage
    }

    /// Extract the first frame from a video (useful for thumbnails)
    /// - Parameter asset: The video asset
    /// - Returns: CGImage of the first frame
    static func extractFirstFrame(from asset: AVAsset) async throws -> CGImage {
        return try await extractFrame(from: asset, at: .zero)
    }

    // MARK: - Video Metadata

    /// Get metadata about a video
    /// - Parameter asset: The video asset
    /// - Returns: VideoMetadata containing duration, dimensions, and frame rate
    static func metadata(for asset: AVAsset) async throws -> VideoMetadata {
        let duration = try await asset.load(.duration)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoError.noVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)

        return VideoMetadata(
            duration: duration,
            dimensions: naturalSize,
            frameRate: nominalFrameRate
        )
    }
}

// MARK: - Supporting Types

/// Video metadata
struct VideoMetadata {
    let duration: CMTime
    let dimensions: CGSize
    let frameRate: Float

    var durationSeconds: Double {
        CMTimeGetSeconds(duration)
    }

    var formattedDuration: String {
        let seconds = Int(durationSeconds)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    var formattedDimensions: String {
        return "\(Int(dimensions.width))×\(Int(dimensions.height))"
    }

    var formattedFrameRate: String {
        return String(format: "%.1f fps", frameRate)
    }
}

/// Errors that can occur during video operations
enum VideoError: LocalizedError {
    case videoNotFound
    case invalidDuration
    case noFramesExtracted
    case noVideoTrack
    case frameExtractionFailed

    var errorDescription: String? {
        switch self {
        case .videoNotFound:
            return "Video file not found in bundle"
        case .invalidDuration:
            return "Video has invalid duration"
        case .noFramesExtracted:
            return "Failed to extract any frames from video"
        case .noVideoTrack:
            return "Video has no video track"
        case .frameExtractionFailed:
            return "Failed to extract frame from video"
        }
    }
}
