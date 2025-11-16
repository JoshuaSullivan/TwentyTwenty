import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Human Rectangles model
@Observable
@MainActor
final class DetectHumanRectanglesViewModel: BaseModelDetailViewModel {
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
        guard !detectedHumans.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateHumanOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected human rectangles from the last analysis
    var detectedHumans: [DetectedHuman] = []

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
        detectedHumans = []

        do {
            let (humans, tracker) = try await PerformanceTracker.measure {
                try await performHumanDetection(on: image)
            }

            detectedHumans = humans
            statistics = PerformanceStatistics(from: tracker)

            if detectedHumans.isEmpty {
                errorMessage = "No human figures detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedHumans = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performHumanDetection(on image: UIImage) async throws -> [DetectedHuman] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectHumanRectanglesRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().map { index, observation in
            DetectedHuman(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateHumanOverlay(for image: UIImage) -> UIImage {
        let rectangles = detectedHumans.map { human in
            let label = String(format: "%.0f%%", human.confidence * 100)
            return (rect: human.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }
}

// MARK: - Detected Human Model

/// Represents a detected human bounding box
struct DetectedHuman: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect

    init(from observation: HumanObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize)
    }

    /// Aspect ratio of the bounding box
    var aspectRatio: Double {
        guard boundingBox.height > 0 else { return 0 }
        return Double(boundingBox.width / boundingBox.height)
    }
}
