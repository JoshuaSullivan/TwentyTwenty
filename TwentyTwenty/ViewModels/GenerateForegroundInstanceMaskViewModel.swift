import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Foreground Instance Mask model
@Observable
@MainActor
final class GenerateForegroundInstanceMaskViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .animals]
    }

    // MARK: - Model-Specific State

    /// Generated foreground instance masks from the last analysis
    var foregroundInstances: [ForegroundInstance] = []

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
        foregroundInstances = []

        do {
            let (instances, tracker) = try await PerformanceTracker.measure {
                try await performForegroundInstanceMaskGeneration(on: image)
            }

            foregroundInstances = instances
            statistics = PerformanceStatistics(from: tracker)

            if foregroundInstances.isEmpty {
                errorMessage = "No foreground objects detected in the image"
            }
        } catch {
            errorMessage = "Mask generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        foregroundInstances = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performForegroundInstanceMaskGeneration(on image: UIImage) async throws -> [ForegroundInstance] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            ForegroundInstance(from: observation, index: index)
        }
    }
}

// MARK: - Foreground Instance Model

/// Represents a foreground instance with segmentation mask
struct ForegroundInstance: Identifiable {
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
