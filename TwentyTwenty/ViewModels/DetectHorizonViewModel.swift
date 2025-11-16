import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Horizon model
@Observable
@MainActor
final class DetectHorizonViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.nature, .architecture]
    }

    var overlayImage: UIImage? {
        guard let horizon = detectedHorizon,
              let image = selectedImage else {
            return nil
        }
        return generateHorizonOverlay(for: image, horizon: horizon)
    }

    // MARK: - Model-Specific State

    /// Detected horizon from the last analysis
    var detectedHorizon: DetectedHorizon?

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Processing

    func processImage() async {
        guard let image = selectedImage else {
            errorMessage = "No image selected"
            return
        }

        isProcessing = true
        errorMessage = nil
        detectedHorizon = nil

        do {
            let (horizon, tracker) = try await PerformanceTracker.measure {
                try await performHorizonDetection(on: image)
            }

            detectedHorizon = horizon
            statistics = PerformanceStatistics(from: tracker)

            if detectedHorizon == nil {
                errorMessage = "No horizon detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedHorizon = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func generateHorizonOverlay(for image: UIImage, horizon: DetectedHorizon) -> UIImage {
        return OverlayRenderer.renderHorizonLine(angle: horizon.angle, imageSize: image.size)
    }

    private func performHorizonDetection(on image: UIImage) async throws -> DetectedHorizon? {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectHorizonRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            return nil
        }

        return DetectedHorizon(from: result, imageSize: image.size)
    }
}

// MARK: - Detected Horizon Model

/// Represents a detected horizon
struct DetectedHorizon {
    let angle: Double
    let transform: CGAffineTransform

    init(from observation: VNHorizonObservation, imageSize: CGSize) {
        self.angle = observation.angle
        self.transform = observation.transform
    }

    var angleDegrees: Double {
        angle * 180 / .pi
    }

    var isLevel: Bool {
        abs(angleDegrees) < 1.0
    }

    var tiltDirection: String {
        if isLevel {
            return "Level"
        } else if angleDegrees > 0 {
            return "Tilted Right"
        } else {
            return "Tilted Left"
        }
    }
}
