import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Document Segmentation model
@Observable
@MainActor
final class DetectDocumentSegmentationViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.documents]
    }

    // MARK: - Model-Specific State

    /// Detected documents from the last analysis
    var detectedDocuments: [DetectedDocument] = []

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
        detectedDocuments = []

        do {
            let (documents, tracker) = try await PerformanceTracker.measure {
                try await performDocumentSegmentation(on: image)
            }

            detectedDocuments = documents
            statistics = PerformanceStatistics(from: tracker)

            if detectedDocuments.isEmpty {
                errorMessage = "No documents detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedDocuments = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performDocumentSegmentation(on image: UIImage) async throws -> [DetectedDocument] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectDocumentSegmentationRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            DetectedDocument(from: observation, index: index, imageSize: image.size)
        }
    }
}

// MARK: - Detected Document Model

/// Represents a detected document region
struct DetectedDocument: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect

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
    }

    /// Area of the document
    var area: Double {
        Double(boundingBox.width * boundingBox.height)
    }

    /// Aspect ratio of the document
    var aspectRatio: Double {
        guard boundingBox.height > 0 else { return 0 }
        return Double(boundingBox.width / boundingBox.height)
    }
}
