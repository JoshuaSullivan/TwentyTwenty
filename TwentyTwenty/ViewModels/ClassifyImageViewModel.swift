import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Classify Image model
@Observable
@MainActor
final class ClassifyImageViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [] // All content types suitable for classification
    }

    // MARK: - Model-Specific State

    /// Image classifications from the last analysis
    var classifications: [ImageClassification] = []

    /// Maximum number of results to return
    var maxResults: Int = 10

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
        classifications = []

        do {
            let (results, tracker) = try await PerformanceTracker.measure {
                try await performImageClassification(on: image)
            }

            classifications = results
            statistics = PerformanceStatistics(from: tracker)

            if classifications.isEmpty {
                errorMessage = "No classifications found"
            }
        } catch {
            errorMessage = "Classification failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        classifications = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performImageClassification(on image: UIImage) async throws -> [ImageClassification] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = ClassifyImageRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations
            .prefix(maxResults)
            .map { ImageClassification(from: $0) }
    }
}

// MARK: - Image Classification Model

/// Represents an image classification result
struct ImageClassification: Identifiable {
    let id = UUID()
    let identifier: String
    let confidence: Float

    init(from observation: ClassificationObservation) {
        self.identifier = observation.identifier
        self.confidence = observation.confidence
    }
}
