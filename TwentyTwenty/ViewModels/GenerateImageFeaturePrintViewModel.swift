import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Image Feature Print model
@Observable
@MainActor
final class GenerateImageFeaturePrintViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .nature, .documents]
    }

    // MARK: - Model-Specific State

    /// Generated feature print results from the last analysis
    var featurePrintResults: [ImageFeaturePrint] = []

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
        featurePrintResults = []

        do {
            let (results, tracker) = try await PerformanceTracker.measure {
                try await performFeaturePrintGeneration(on: image)
            }

            featurePrintResults = results
            statistics = PerformanceStatistics(from: tracker)

            if featurePrintResults.isEmpty {
                errorMessage = "Failed to generate feature print"
            }
        } catch {
            errorMessage = "Feature print generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        featurePrintResults = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performFeaturePrintGeneration(on image: UIImage) async throws -> [ImageFeaturePrint] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GenerateImageFeaturePrintRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        return [ImageFeaturePrint(from: observation, index: 0)]
    }
}

// MARK: - Image Feature Print Model

/// Represents an image feature print result
struct ImageFeaturePrint: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let elementCount: Int
    let elementType: String

    init(from observation: FeaturePrintObservation, index: Int) {
        self.index = index
        self.confidence = observation.confidence
        self.elementCount = observation.elementCount

        // Determine element type based on observation
        switch observation.elementType {
        case .float:
            self.elementType = "Float"
        case .double:
            self.elementType = "Double"
        @unknown default:
            self.elementType = "Unknown"
        }
    }
}
