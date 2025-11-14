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

    private func performRectangleDetection(on image: UIImage) async throws -> [DetectedRectangle] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = VNAspectRatio(minimumAspectRatio)
        request.maximumAspectRatio = VNAspectRatio(maximumAspectRatio)
        request.minimumConfidence = 0.5

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
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

    init(from observation: VNRectangleObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )

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
