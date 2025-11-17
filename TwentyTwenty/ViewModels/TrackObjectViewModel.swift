import Foundation
import UIKit
import Vision
import AVFoundation
import Observation

/// ViewModel for the Track Object model
@Observable
@MainActor
final class TrackObjectViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var selectedVideo: AVAsset?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .animals]
    }

    var requiresVideo: Bool {
        true
    }

    // MARK: - Model-Specific State

    /// Detected tracks from video analysis
    var detectedTracks: [ObjectTrack] = []

    /// First frame of the video for object selection
    var firstFrame: UIImage?

    /// User-selected bounding box for initial object
    var selectedBoundingBox: CGRect?

    /// Number of frames to extract from video
    private let frameCount = 30

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Video Loading

    /// Load the first frame when video is selected for object selection UI
    func loadFirstFrame() async {
        guard let video = selectedVideo else {
            firstFrame = nil
            return
        }

        do {
            let cgImage = try await VideoManager.extractFirstFrame(from: video)
            await MainActor.run {
                self.firstFrame = UIImage(cgImage: cgImage)
            }
        } catch {
            print("Failed to load first frame: \(error)")
            await MainActor.run {
                self.firstFrame = nil
            }
        }
    }

    // MARK: - Processing

    func processImage() async {
        errorMessage = "This model requires video input. Please select a video instead."
        isProcessing = false
    }

    func processVideo() async {
        guard let video = selectedVideo else {
            errorMessage = "No video selected"
            return
        }

        guard let boundingBox = selectedBoundingBox else {
            errorMessage = "Please select an object to track first"
            return
        }

        isProcessing = true
        errorMessage = nil
        detectedTracks = []

        do {
            let (tracks, tracker) = try await PerformanceTracker.measure {
                try await performObjectTracking(on: video, initialBox: boundingBox)
            }

            detectedTracks = tracks
            statistics = PerformanceStatistics(from: tracker)

            if detectedTracks.isEmpty {
                errorMessage = "Failed to track the selected object"
            }
        } catch {
            errorMessage = "Tracking failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedTracks = []
        selectedBoundingBox = nil
        firstFrame = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performObjectTracking(on video: AVAsset, initialBox: CGRect) async throws -> [ObjectTrack] {
        // Extract frames from video
        let frames = try await VideoManager.extractFrames(from: video, frameCount: frameCount)

        guard !frames.isEmpty else {
            throw VideoError.noFramesExtracted
        }

        // NOTE: Object tracking is not yet available in the modern Vision API (iOS 18)
        // We need to use the legacy VNTrackObjectRequest from the VN* framework

        // Convert the user-selected bounding box to Vision coordinates
        // The box is in normalized coordinates (0-1) with top-left origin (SwiftUI)
        // Vision uses bottom-left origin, so we need to flip Y
        let visionBox = CGRect(
            x: initialBox.origin.x,
            y: 1.0 - initialBox.origin.y - initialBox.size.height,
            width: initialBox.size.width,
            height: initialBox.size.height
        )

        var trackResults: [TrackResult] = []
        var lastObservation: VNDetectedObjectObservation?

        // Create initial observation for the first frame
        let inputObservation = VNDetectedObjectObservation(boundingBox: visionBox)

        // Track the object across all frames
        for (index, frame) in frames.enumerated() {
            // Create tracking request
            let request: VNTrackObjectRequest

            if index == 0 {
                // First frame: use the user-selected box
                request = VNTrackObjectRequest(detectedObjectObservation: inputObservation)
            } else if let previousObservation = lastObservation {
                // Subsequent frames: track from previous observation
                request = VNTrackObjectRequest(detectedObjectObservation: previousObservation)
            } else {
                // Lost tracking, mark as failed
                trackResults.append(TrackResult(
                    frameIndex: index,
                    boundingBox: NormalizedRect(x: 0, y: 0, width: 0, height: 0),
                    confidence: 0.0
                ))
                continue
            }

            request.trackingLevel = .accurate

            // Perform the tracking request
            let handler = VNImageRequestHandler(cgImage: frame, options: [:])

            do {
                try handler.perform([request])

                if let observation = request.results?.first as? VNDetectedObjectObservation {
                    // Convert VNDetectedObjectObservation boundingBox to NormalizedRect
                    let box = observation.boundingBox
                    trackResults.append(TrackResult(
                        frameIndex: index,
                        boundingBox: NormalizedRect(
                            x: box.origin.x,
                            y: box.origin.y,
                            width: box.width,
                            height: box.height
                        ),
                        confidence: observation.confidence
                    ))

                    // Update for next frame
                    lastObservation = observation
                } else {
                    // Tracking lost
                    trackResults.append(TrackResult(
                        frameIndex: index,
                        boundingBox: NormalizedRect(x: 0, y: 0, width: 0, height: 0),
                        confidence: 0.0
                    ))
                    lastObservation = nil
                }
            } catch {
                // Tracking failed for this frame
                print("Tracking error at frame \(index): \(error)")
                trackResults.append(TrackResult(
                    frameIndex: index,
                    boundingBox: NormalizedRect(x: 0, y: 0, width: 0, height: 0),
                    confidence: 0.0
                ))
                lastObservation = nil
            }
        }

        return [ObjectTrack(results: trackResults, totalFrames: frameCount)]
    }
}

// MARK: - Object Track Model

/// Represents a tracked object across video frames
struct ObjectTrack: Identifiable {
    let id = UUID()
    let results: [TrackResult]
    let totalFrames: Int

    /// Number of frames where tracking was successful
    var successfulFrames: Int {
        results.filter { $0.confidence > 0.0 }.count
    }

    /// Average confidence across successful frames
    var averageConfidence: Float {
        let successful = results.filter { $0.confidence > 0.0 }
        guard !successful.isEmpty else { return 0 }
        return successful.reduce(0) { $0 + $1.confidence } / Float(successful.count)
    }

    /// Tracking success rate as percentage
    var successRate: Double {
        Double(successfulFrames) / Double(totalFrames) * 100
    }
}

/// Result for a single frame in object tracking
struct TrackResult: Identifiable {
    let id = UUID()
    let frameIndex: Int
    let boundingBox: NormalizedRect
    let confidence: Float

    var wasTracked: Bool {
        confidence > 0.0
    }
}
