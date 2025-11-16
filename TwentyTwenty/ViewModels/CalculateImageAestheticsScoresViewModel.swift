import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Calculate Image Aesthetics Scores model
@Observable
@MainActor
final class CalculateImageAestheticsScoresViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [] // All image types suitable for aesthetics scoring
    }

    // MARK: - Model-Specific State

    /// Aesthetics scores from the last analysis
    var aestheticsScores: ImageAestheticsScores?

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
        aestheticsScores = nil

        do {
            let (scores, tracker) = try await PerformanceTracker.measure {
                try await performAestheticsCalculation(on: image)
            }

            aestheticsScores = scores
            statistics = PerformanceStatistics(from: tracker)

            if aestheticsScores == nil {
                errorMessage = "Failed to calculate aesthetics scores"
            }
        } catch {
            errorMessage = "Calculation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        aestheticsScores = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performAestheticsCalculation(on image: UIImage) async throws -> ImageAestheticsScores? {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        if #available(iOS 18.0, *) {
            let request = CalculateImageAestheticsScoresRequest()
            let observation = try await request.perform(on: cgImage, orientation: nil)

            return ImageAestheticsScores(from: observation)
        } else {
            throw VisionError.invalidImage
        }
    }
}

// MARK: - Image Aesthetics Scores Model

/// Represents image aesthetics scores
struct ImageAestheticsScores {
    let overallScore: Float

    init(from observation: ImageAestheticsScoresObservation) {
        self.overallScore = observation.overallScore
    }

    var overallScorePercentage: Float {
        overallScore * 100
    }

    var qualityRating: String {
        switch overallScore {
        case 0.8...1.0:
            return "Excellent"
        case 0.6..<0.8:
            return "Good"
        case 0.4..<0.6:
            return "Average"
        case 0.2..<0.4:
            return "Below Average"
        default:
            return "Poor"
        }
    }

    var qualityColor: String {
        switch overallScore {
        case 0.8...1.0:
            return "green"
        case 0.6..<0.8:
            return "blue"
        case 0.4..<0.6:
            return "orange"
        default:
            return "red"
        }
    }
}
