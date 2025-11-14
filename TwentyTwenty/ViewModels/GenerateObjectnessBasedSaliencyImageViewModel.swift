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

    private func performObjectnessSaliencyGeneration(on image: UIImage) async throws -> [ObjectnessSaliency] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNGenerateObjectnessBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            ObjectnessSaliency(from: observation, index: index, imageSize: image.size)
        }
    }
}

// MARK: - Objectness Saliency Model

/// Represents objectness-based saliency results
struct ObjectnessSaliency: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let salientObjects: [SalientObject]

    init(from observation: VNSaliencyImageObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Extract salient object regions
        self.salientObjects = (observation.salientObjects ?? []).enumerated().map { objIndex, object in
            let box = object.boundingBox
            let boundingBox = CGRect(
                x: box.origin.x * imageSize.width,
                y: (1 - box.origin.y - box.height) * imageSize.height,
                width: box.width * imageSize.width,
                height: box.height * imageSize.height
            )
            return SalientObject(index: objIndex, confidence: object.confidence, boundingBox: boundingBox)
        }
    }
}
