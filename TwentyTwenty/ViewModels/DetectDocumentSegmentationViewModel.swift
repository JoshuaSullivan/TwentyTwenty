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
    var selectedImage: UIImage? {
        didSet {
            clearResults()
        }
    }
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.documents]
    }

    var overlayImage: UIImage? {
        guard !detectedDocuments.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateDocumentOverlay(for: image)
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

        let request = DetectDocumentSegmentationRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        if let observation = observation {
            return [DetectedDocument(from: observation, index: 0, imageSize: image.size)]
        } else {
            return []
        }
    }

    private func generateDocumentOverlay(for image: UIImage) -> UIImage {
        let rectangles = detectedDocuments.map { document in
            let label = String(format: "%.0f%%", document.confidence * 100)
            return (rect: document.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }
}

// MARK: - Detected Document Model

/// Represents a detected document region
struct DetectedDocument: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect

    init(from observation: DetectedDocumentObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert quadrilateral to bounding box
        let points = [
            observation.topLeft,
            observation.topRight,
            observation.bottomRight,
            observation.bottomLeft
        ]

        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0

        self.boundingBox = CGRect(
            x: minX * imageSize.width,
            y: (1 - maxY) * imageSize.height,
            width: (maxX - minX) * imageSize.width,
            height: (maxY - minY) * imageSize.height
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
