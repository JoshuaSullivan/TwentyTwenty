import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Rectangles model
@Observable
@MainActor
final class DetectRectanglesViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.documents, .architecture]
    }

    var overlayImage: UIImage? {
        guard !detectedRectangles.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateRectangleOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected rectangles from the last analysis
    var detectedRectangles: [DetectedRectangle] = []

    /// Minimum aspect ratio for detected rectangles
    var minimumAspectRatio: Float = 0.0

    /// Maximum aspect ratio for detected rectangles
    var maximumAspectRatio: Float = 1.0

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
        detectedRectangles = []

        do {
            let (rectangles, tracker) = try await PerformanceTracker.measure {
                try await performRectangleDetection(on: image)
            }

            detectedRectangles = rectangles
            statistics = PerformanceStatistics(from: tracker)

            if detectedRectangles.isEmpty {
                errorMessage = "No rectangles detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedRectangles = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func generateRectangleOverlay(for image: UIImage) -> UIImage {
        let rectangles = detectedRectangles.map { rectangle in
            let label = String(format: "%.2f", rectangle.confidence)
            return (rect: rectangle.boundingBox, label: label)
        }
        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }

    private func performRectangleDetection(on image: UIImage) async throws -> [DetectedRectangle] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        var request = DetectRectanglesRequest()
        request.minimumAspectRatio = minimumAspectRatio
        request.maximumAspectRatio = maximumAspectRatio
        request.minimumConfidence = 0.5

        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().map { index, observation in
            DetectedRectangle(from: observation, index: index, imageSize: image.size)
        }
    }
}

// MARK: - Detected Rectangle Model

/// Represents a detected rectangle
struct DetectedRectangle: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    init(from observation: RectangleObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)

        // Convert corner points
        self.topLeft = CGPoint(
            x: observation.topLeft.x * imageSize.width,
            y: (1 - observation.topLeft.y) * imageSize.height
        )
        self.topRight = CGPoint(
            x: observation.topRight.x * imageSize.width,
            y: (1 - observation.topRight.y) * imageSize.height
        )
        self.bottomLeft = CGPoint(
            x: observation.bottomLeft.x * imageSize.width,
            y: (1 - observation.bottomLeft.y) * imageSize.height
        )
        self.bottomRight = CGPoint(
            x: observation.bottomRight.x * imageSize.width,
            y: (1 - observation.bottomRight.y) * imageSize.height
        )
    }

    var aspectRatio: Float {
        Float(boundingBox.width / boundingBox.height)
    }
}
