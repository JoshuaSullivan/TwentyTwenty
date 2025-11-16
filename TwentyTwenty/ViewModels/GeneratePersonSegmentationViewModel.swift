import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Person Segmentation model
@Observable
@MainActor
final class GeneratePersonSegmentationViewModel: BaseModelDetailViewModel {
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
        guard let result = segmentationResult,
              let image = selectedImage,
              let maskImage = try? result.observation.cgImage else {
            return nil
        }
        return UIImage(cgImage: maskImage)
    }

    // MARK: - Model-Specific State

    /// Generated person segmentation result from the last analysis
    var segmentationResult: PersonSegmentation?

    /// Quality level for segmentation (accurate vs. balanced)
    var qualityLevel: GeneratePersonSegmentationRequest.QualityLevel = .balanced

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
        segmentationResult = nil

        do {
            let (result, tracker) = try await PerformanceTracker.measure {
                try await performPersonSegmentation(on: image)
            }

            segmentationResult = result
            statistics = PerformanceStatistics(from: tracker)

            if segmentationResult == nil {
                errorMessage = "No people detected in the image"
            }
        } catch {
            errorMessage = "Segmentation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        segmentationResult = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performPersonSegmentation(on image: UIImage) async throws -> PersonSegmentation? {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        var request = GeneratePersonSegmentationRequest()
        request.qualityLevel = qualityLevel

        let observation = try await request.perform(on: cgImage, orientation: nil)

        return PersonSegmentation(from: observation)
    }
}

// MARK: - Person Segmentation Model

/// Represents a person segmentation result
struct PersonSegmentation: Identifiable {
    let id = UUID()
    let confidence: Float
    let observation: PixelBufferObservation

    init(from observation: PixelBufferObservation) {
        self.confidence = observation.confidence
        self.observation = observation
    }
}
