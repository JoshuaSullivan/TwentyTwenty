import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Objectness-Based Saliency Image model
@Observable
@MainActor
final class GenerateObjectnessBasedSaliencyImageViewModel: BaseModelDetailViewModel {
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
              let image = selectedImage else {
            return nil
        }
        return generateSaliencyOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Generated objectness saliency results from the last analysis
    var saliencyResults: [ObjectnessSaliency] = []

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
                try await performObjectnessSaliencyGeneration(on: image)
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

    private func generateSaliencyOverlay(for image: UIImage) -> UIImage {
        let rectangles = saliencyResults.flatMap { result in
            result.salientObjects.map { object in
                let label = String(format: "%.2f", object.confidence)
                return (rect: object.boundingBox, label: label)
            }
        }
        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }

    private func performObjectnessSaliencyGeneration(on image: UIImage) async throws -> [ObjectnessSaliency] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GenerateObjectnessBasedSaliencyImageRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        return [ObjectnessSaliency(from: observation, index: 0, imageSize: image.size)]
    }
}

// MARK: - Objectness Saliency Model

/// Represents objectness-based saliency results
struct ObjectnessSaliency: Identifiable {
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
