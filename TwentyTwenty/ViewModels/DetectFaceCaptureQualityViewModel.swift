import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Face Capture Quality model
@Observable
@MainActor
final class DetectFaceCaptureQualityViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.people]
    }

    var overlayImage: UIImage? {
        guard !faceQualityResults.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateFaceQualityOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected faces with quality scores from the last analysis
    var faceQualityResults: [FaceQualityResult] = []

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
        faceQualityResults = []

        do {
            let (results, tracker) = try await PerformanceTracker.measure {
                try await performFaceCaptureQualityDetection(on: image)
            }

            faceQualityResults = results
            statistics = PerformanceStatistics(from: tracker)

            if faceQualityResults.isEmpty {
                errorMessage = "No faces detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        faceQualityResults = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performFaceCaptureQualityDetection(on image: UIImage) async throws -> [FaceQualityResult] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectFaceCaptureQualityRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().map { index, observation in
            FaceQualityResult(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateFaceQualityOverlay(for image: UIImage) -> UIImage {
        let rectangles = faceQualityResults.map { result in
            let label = String(format: "%@ (%.0f%%)", result.qualityRating, result.quality * 100)
            return (rect: result.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }
}

// MARK: - Face Quality Result Model

/// Represents a detected face with quality score
struct FaceQualityResult: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let quality: Float
    let boundingBox: CGRect

    init(from observation: FaceObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence
        self.quality = observation.captureQuality?.score ?? 0.0

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize)
    }

    /// Quality rating based on score
    var qualityRating: String {
        if quality > 0.7 {
            return "Excellent"
        } else if quality > 0.5 {
            return "Good"
        } else if quality > 0.3 {
            return "Fair"
        } else {
            return "Poor"
        }
    }

    /// Color for quality score
    var qualityColor: String {
        if quality > 0.7 {
            return "green"
        } else if quality > 0.5 {
            return "orange"
        } else {
            return "red"
        }
    }
}
