import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Contours model
@Observable
@MainActor
final class DetectContoursViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .nature]
    }

    var overlayImage: UIImage? {
        guard !detectedContours.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateContoursOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected contours from the last analysis
    var detectedContours: [DetectedContour] = []

    /// Contrast threshold for contour detection (0.0 - 1.0)
    var contrastThreshold: Float = 0.5

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
        detectedContours = []

        do {
            let (contours, tracker) = try await PerformanceTracker.measure {
                try await performContourDetection(on: image)
            }

            detectedContours = contours
            statistics = PerformanceStatistics(from: tracker)

            if detectedContours.isEmpty {
                errorMessage = "No contours detected. Try adjusting the contrast threshold."
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedContours = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func generateContoursOverlay(for image: UIImage) -> UIImage {
        // Collect all contours from all detected contour sets
        let allContours = detectedContours.flatMap { $0.contours }
        return OverlayRenderer.renderContours(allContours, imageSize: image.size)
    }

    private func performContourDetection(on image: UIImage) async throws -> [DetectedContour] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectContoursRequest()
        request.contrastAdjustment = contrastThreshold

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().compactMap { index, observation in
            DetectedContour(from: observation, index: index)
        }
    }
}

// MARK: - Detected Contour Model

/// Represents a detected contour
struct DetectedContour: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let pointCount: Int
    let childContourCount: Int
    let aspectRatio: Float
    let contours: [VNContour]

    init?(from observation: VNContoursObservation, index: Int) {
        self.index = index
        self.confidence = observation.confidence

        // Get all contours (top-level and children)
        self.contours = observation.topLevelContours

        // Get the top-level contour for stats
        guard let topLevelContour = observation.topLevelContours.first else {
            return nil
        }

        self.pointCount = topLevelContour.normalizedPoints.count
        self.childContourCount = topLevelContour.childContourCount
        self.aspectRatio = topLevelContour.aspectRatio
    }
}
