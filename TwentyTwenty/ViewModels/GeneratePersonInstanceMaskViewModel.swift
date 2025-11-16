import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Person Instance Mask model
@Observable
@MainActor
final class GeneratePersonInstanceMaskViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.people]
    }

    var overlayImage: UIImage? {
        // TODO: VNInstanceMaskObservation requires different API to extract masks
        return nil
    }

    // MARK: - Model-Specific State

    /// Generated person instance masks from the last analysis
    var personInstances: [PersonInstance] = []

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
        personInstances = []

        do {
            let (instances, tracker) = try await PerformanceTracker.measure {
                try await performPersonInstanceMaskGeneration(on: image)
            }

            personInstances = instances
            statistics = PerformanceStatistics(from: tracker)

            if personInstances.isEmpty {
                errorMessage = "No people detected in the image"
            }
        } catch {
            errorMessage = "Mask generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        personInstances = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performPersonInstanceMaskGeneration(on image: UIImage) async throws -> [PersonInstance] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNGeneratePersonInstanceMaskRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            PersonInstance(from: observation, index: index)
        }
    }
}

// MARK: - Person Instance Model

/// Represents a person instance with segmentation mask
struct PersonInstance: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let instanceCount: Int

    init(from observation: VNInstanceMaskObservation, index: Int) {
        self.index = index
        self.confidence = observation.confidence

        // Get all instances from the mask
        self.instanceCount = observation.allInstances.count
    }
}
