import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Text Rectangles model
@Observable
@MainActor
final class DetectTextRectanglesViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.documents, .text]
    }

    var overlayImage: UIImage? {
        guard !textRectangles.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateTextOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected text rectangles from the last analysis
    var textRectangles: [DetectedTextRectangle] = []

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
        textRectangles = []

        do {
            let (rectangles, tracker) = try await PerformanceTracker.measure {
                try await performTextRectangleDetection(on: image)
            }

            textRectangles = rectangles
            statistics = PerformanceStatistics(from: tracker)

            if textRectangles.isEmpty {
                errorMessage = "No text regions detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        textRectangles = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performTextRectangleDetection(on image: UIImage) async throws -> [DetectedTextRectangle] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            DetectedTextRectangle(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateTextOverlay(for image: UIImage) -> UIImage {
        let rectangles = textRectangles.map { rect in
            (rect: rect.boundingBox, label: nil as String?)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size, lineWidth: 2)
    }
}

// MARK: - Detected Text Rectangle Model

/// Represents a detected text region
struct DetectedTextRectangle: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect

    init(from observation: VNTextObservation, index: Int, imageSize: CGSize) {
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
    }

    /// Area of the text rectangle
    var area: Double {
        Double(boundingBox.width * boundingBox.height)
    }
}
