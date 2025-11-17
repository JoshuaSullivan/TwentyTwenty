import Foundation
import UIKit
import Vision
import AVFoundation
import Observation

/// ViewModel for the Track Rectangle model
@Observable
@MainActor
final class TrackRectangleViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var selectedVideo: AVAsset?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .documents]
    }

    var requiresVideo: Bool {
        true
    }

    // MARK: - Model-Specific State

    /// Detected rectangle tracks from video analysis
    var detectedTracks: [RectangleTrack] = []

    /// First frame of the video for rectangle selection
    var firstFrame: UIImage?

    /// User-selected rectangle corners
    var selectedRectangle: (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint)?

    /// Number of frames to extract from video
    private let frameCount = 30

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Video Loading

    /// Load the first frame when video is selected for rectangle selection UI
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

        guard let rectangle = selectedRectangle else {
            errorMessage = "Please select a rectangle to track first"
            return
        }

        isProcessing = true
        errorMessage = nil
        detectedTracks = []

        do {
            let (tracks, tracker) = try await PerformanceTracker.measure {
                try await performRectangleTracking(on: video, initialRectangle: rectangle)
            }

            detectedTracks = tracks
            statistics = PerformanceStatistics(from: tracker)

            if detectedTracks.isEmpty {
                errorMessage = "Failed to track the selected rectangle"
            }
        } catch {
            errorMessage = "Tracking failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedTracks = []
        selectedRectangle = nil
        firstFrame = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performRectangleTracking(
        on video: AVAsset,
        initialRectangle: (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint)
    ) async throws -> [RectangleTrack] {
        // Extract frames from video
        let frames = try await VideoManager.extractFrames(from: video, frameCount: frameCount)

        guard !frames.isEmpty else {
            throw VideoError.noFramesExtracted
        }

        // Convert corners to normalized coordinates with Vision's bottom-left origin
        let initialObservation = RectangleObservation(
            topLeft: NormalizedPoint(
                x: initialRectangle.topLeft.x,
                y: 1.0 - initialRectangle.topLeft.y
            ),
            topRight: NormalizedPoint(
                x: initialRectangle.topRight.x,
                y: 1.0 - initialRectangle.topRight.y
            ),
            bottomRight: NormalizedPoint(
                x: initialRectangle.bottomRight.x,
                y: 1.0 - initialRectangle.bottomRight.y
            ),
            bottomLeft: NormalizedPoint(
                x: initialRectangle.bottomLeft.x,
                y: 1.0 - initialRectangle.bottomLeft.y
            )
        )

        var trackResults: [RectangleTrackResult] = []
        var currentObservation = initialObservation

        // Track the rectangle across all frames
        for (index, frame) in frames.enumerated() {
            let request = TrackRectangleRequest(detectedRectangle: currentObservation)
            request.trackingLevel = .accurate

            do {
                let observation = try await request.perform(on: frame, orientation: .up)

                if let observation = observation {
                    trackResults.append(RectangleTrackResult(
                        frameIndex: index,
                        topLeft: observation.topLeft,
                        topRight: observation.topRight,
                        bottomRight: observation.bottomRight,
                        bottomLeft: observation.bottomLeft,
                        confidence: observation.confidence
                    ))

                    // Update for next frame
                    currentObservation = observation
                } else {
                    // Tracking lost
                    let emptyPoint = NormalizedPoint(x: 0, y: 0)
                    trackResults.append(RectangleTrackResult(
                        frameIndex: index,
                        topLeft: emptyPoint,
                        topRight: emptyPoint,
                        bottomRight: emptyPoint,
                        bottomLeft: emptyPoint,
                        confidence: 0.0
                    ))
                }
            } catch {
                print("Tracking error at frame \(index): \(error)")
                let emptyPoint = NormalizedPoint(x: 0, y: 0)
                trackResults.append(RectangleTrackResult(
                    frameIndex: index,
                    topLeft: emptyPoint,
                    topRight: emptyPoint,
                    bottomRight: emptyPoint,
                    bottomLeft: emptyPoint,
                    confidence: 0.0
                ))
            }
        }

        return [RectangleTrack(results: trackResults, totalFrames: frameCount)]
    }
}

// MARK: - Rectangle Track Model

/// Represents a tracked rectangle across video frames
struct RectangleTrack: Identifiable {
    let id = UUID()
    let results: [RectangleTrackResult]
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

/// Result for a single frame in rectangle tracking
struct RectangleTrackResult: Identifiable {
    let id = UUID()
    let frameIndex: Int
    let topLeft: NormalizedPoint
    let topRight: NormalizedPoint
    let bottomRight: NormalizedPoint
    let bottomLeft: NormalizedPoint
    let confidence: Float

    var wasTracked: Bool {
        confidence > 0.0
    }
}
