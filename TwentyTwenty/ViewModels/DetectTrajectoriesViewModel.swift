import Foundation
import UIKit
import Vision
import AVFoundation
import Observation

/// ViewModel for the Detect Trajectories model
@Observable
@MainActor
final class DetectTrajectoriesViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var selectedVideo: AVAsset?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people]
    }

    var requiresVideo: Bool {
        true
    }

    // MARK: - Model-Specific State

    /// Detected trajectories from video analysis
    var detectedTrajectories: [TrajectoryObservation] = []

    /// Number of frames for trajectory analysis
    private let trajectoryLength = 30

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
        detectedTrajectories = []

        do {
            let (trajectories, tracker) = try await PerformanceTracker.measure {
                try await performTrajectoryDetection(on: video)
            }

            detectedTrajectories = trajectories
            statistics = PerformanceStatistics(from: tracker)

            if detectedTrajectories.isEmpty {
                errorMessage = "No trajectories detected in video"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedTrajectories = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performTrajectoryDetection(on video: AVAsset) async throws -> [TrajectoryObservation] {
        // Extract frames from video
        let frames = try await VideoManager.extractFrames(from: video, frameCount: trajectoryLength)

        guard !frames.isEmpty else {
            throw VideoError.noFramesExtracted
        }

        // Create trajectory detection request
        let request = DetectTrajectoriesRequest(trajectoryLength: trajectoryLength)

        // Process all frames to detect trajectories
        var allTrajectories: [TrajectoryObservation] = []

        for frame in frames {
            do {
                let observations = try await request.perform(on: frame, orientation: .up)
                allTrajectories.append(contentsOf: observations)
            } catch {
                print("Trajectory detection error: \(error)")
            }
        }

        return allTrajectories
    }
}
