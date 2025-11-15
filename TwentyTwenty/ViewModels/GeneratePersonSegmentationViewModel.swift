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
        guard !segmentationResults.isEmpty,
              let image = selectedImage,
              let firstMask = segmentationResults.first?.pixelBuffer else {
            return nil
        }
        return OverlayRenderer.renderBitmapMask(firstMask, imageSize: image.size)
    }

    // MARK: - Model-Specific State

    /// Generated person segmentation results from the last analysis
    var segmentationResults: [PersonSegmentation] = []

    /// Quality level for segmentation (accurate vs. balanced)
    var qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced

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
        segmentationResults = []

        do {
            let (results, tracker) = try await PerformanceTracker.measure {
                try await performPersonSegmentation(on: image)
            }

            segmentationResults = results
            statistics = PerformanceStatistics(from: tracker)

            if segmentationResults.isEmpty {
                errorMessage = "No people detected in the image"
            }
        } catch {
            errorMessage = "Segmentation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        segmentationResults = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performPersonSegmentation(on image: UIImage) async throws -> [PersonSegmentation] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = qualityLevel

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            PersonSegmentation(from: observation, index: index)
        }
    }
}

// MARK: - Person Segmentation Model

/// Represents a person segmentation result
struct PersonSegmentation: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let pixelBuffer: CVPixelBuffer

    init(from observation: VNPixelBufferObservation, index: Int) {
        self.index = index
        self.confidence = observation.confidence
        self.pixelBuffer = observation.pixelBuffer
    }
}
