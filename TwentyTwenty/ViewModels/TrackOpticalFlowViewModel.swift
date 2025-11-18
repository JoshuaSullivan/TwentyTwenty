import Foundation
import UIKit
import Vision
import AVFoundation
import Observation

/// ViewModel for the Track Optical Flow model
@Observable
@MainActor
final class TrackOpticalFlowViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var selectedVideo: AVAsset?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .nature]
    }

    var requiresVideo: Bool {
        true
    }

    // MARK: - Model-Specific State

    /// Optical flow observations from video analysis
    var opticalFlowResults: [OpticalFlowResult] = []

    /// Number of consecutive frame pairs to analyze
    private let frameCount = 30

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
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

        isProcessing = true
        errorMessage = nil
        opticalFlowResults = []

        do {
            let (results, tracker) = try await PerformanceTracker.measure {
                try await performOpticalFlowTracking(on: video)
            }

            opticalFlowResults = results
            statistics = PerformanceStatistics(from: tracker)

            if opticalFlowResults.isEmpty {
                errorMessage = "No optical flow data generated"
            }
        } catch {
            errorMessage = "Processing failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        opticalFlowResults = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performOpticalFlowTracking(on video: AVAsset) async throws -> [OpticalFlowResult] {
        // Extract frames from video
        let frames = try await VideoManager.extractFrames(from: video, frameCount: frameCount)

        guard frames.count >= 2 else {
            throw VideoError.noFramesExtracted
        }

        var results: [OpticalFlowResult] = []

        // Create optical flow request
        let request = TrackOpticalFlowRequest()
        request.computationAccuracy = .medium

        // Process consecutive frame pairs
        for i in 0..<(frames.count - 1) {
            do {
                let observation = try await request.perform(on: frames[i + 1], orientation: .up)

                if let observation = observation {
                    results.append(OpticalFlowResult(
                        framePairIndex: i,
                        observation: observation
                    ))
                }
            } catch {
                print("Optical flow error at frame pair \(i): \(error)")
            }
        }

        return results
    }
}

// MARK: - Optical Flow Result Model

/// Result for optical flow between consecutive frames
struct OpticalFlowResult: Identifiable {
    let id = UUID()
    let framePairIndex: Int
    let observation: OpticalFlowObservation

    var wasSuccessful: Bool {
        observation.confidence > 0.0
    }

    var confidence: Float {
        observation.confidence
    }

    var size: CGSize {
        observation.size
    }
}
