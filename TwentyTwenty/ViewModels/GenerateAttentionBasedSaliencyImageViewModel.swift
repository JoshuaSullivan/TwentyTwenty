import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Attention-Based Saliency Image model
@Observable
@MainActor
final class GenerateAttentionBasedSaliencyImageViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .nature]
    }

    var overlayImage: UIImage? {
        guard !saliencyResults.isEmpty,
              let image = selectedImage,
              let firstResult = saliencyResults.first else {
            return nil
        }
        return generateSaliencyOverlay(for: image, result: firstResult)
    }

    // MARK: - Model-Specific State

    /// Generated saliency results from the last analysis
    var saliencyResults: [AttentionSaliency] = []

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
        saliencyResults = []

        do {
            let (results, tracker) = try await PerformanceTracker.measure {
                try await performAttentionSaliencyGeneration(on: image)
            }

            saliencyResults = results
            statistics = PerformanceStatistics(from: tracker)

            if saliencyResults.isEmpty {
                errorMessage = "Failed to generate saliency map"
            }
        } catch {
            errorMessage = "Saliency generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        saliencyResults = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performAttentionSaliencyGeneration(on image: UIImage) async throws -> [AttentionSaliency] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GenerateAttentionBasedSaliencyImageRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        return [AttentionSaliency(from: observation, index: 0, imageSize: image.size)]
    }

    private func generateSaliencyOverlay(for image: UIImage, result: AttentionSaliency) -> UIImage {
        let rectangles = result.salientObjects.map { object in
            let label = String(format: "%.0f%%", object.confidence * 100)
            return (rect: object.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }
}

// MARK: - Attention Saliency Model

/// Represents attention-based saliency results
struct AttentionSaliency: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let salientObjects: [SalientObject]

    init(from observation: SaliencyImageObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Extract salient object regions
        self.salientObjects = observation.salientObjects.enumerated().map { objIndex, object in
            // Convert quadrilateral to bounding box
            let points = [
                object.topLeft,
                object.topRight,
                object.bottomRight,
                object.bottomLeft
            ]

            let minX = points.map { $0.x }.min() ?? 0
            let maxX = points.map { $0.x }.max() ?? 0
            let minY = points.map { $0.y }.min() ?? 0
            let maxY = points.map { $0.y }.max() ?? 0

            let boundingBox = CGRect(
                x: minX * imageSize.width,
                y: (1 - maxY) * imageSize.height,
                width: (maxX - minX) * imageSize.width,
                height: (maxY - minY) * imageSize.height
            )
            return SalientObject(index: objIndex, confidence: object.confidence, boundingBox: boundingBox)
        }
    }
}

/// Represents a salient object
struct SalientObject: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect
}
