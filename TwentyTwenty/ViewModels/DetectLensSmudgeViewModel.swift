import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Lens Smudge model
@Observable
@MainActor
final class DetectLensSmudgeViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        []
    }

    // MARK: - Model-Specific State

    /// Smudge detection result from the last analysis
    var smudgeResult: LensSmudgeResult?

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
        smudgeResult = nil

        do {
            let (result, tracker) = try await PerformanceTracker.measure {
                try await performSmudgeDetection(on: image)
            }

            smudgeResult = result
            statistics = PerformanceStatistics(from: tracker)

            if smudgeResult == nil {
                errorMessage = "Failed to detect lens smudge"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        smudgeResult = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performSmudgeDetection(on image: UIImage) async throws -> LensSmudgeResult? {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        if #available(iOS 26.0, *) {
            let request = DetectLensSmudgeRequest()
            let observation = try await request.perform(on: cgImage, orientation: nil)

            return LensSmudgeResult(from: observation)
        } else {
            throw VisionError.invalidImage
        }
    }
}

// MARK: - Lens Smudge Result Model

/// Represents lens smudge detection result
struct LensSmudgeResult {
    let confidence: Float

    init(from observation: SmudgeObservation) {
        self.confidence = observation.confidence
    }

    var confidencePercentage: Float {
        confidence * 100
    }

    var detectionStatus: String {
        switch confidence {
        case 0.8...1.0:
            return "Smudge Detected"
        case 0.5..<0.8:
            return "Possible Smudge"
        case 0.3..<0.5:
            return "Minor Issue"
        default:
            return "Lens Clear"
        }
    }

    var statusColor: String {
        switch confidence {
        case 0.8...1.0:
            return "red"
        case 0.5..<0.8:
            return "orange"
        case 0.3..<0.5:
            return "yellow"
        default:
            return "green"
        }
    }

    var recommendation: String {
        switch confidence {
        case 0.8...1.0:
            return "Clean your camera lens for better image quality"
        case 0.5..<0.8:
            return "Consider cleaning your lens if images appear unclear"
        case 0.3..<0.5:
            return "Lens condition is acceptable"
        default:
            return "Your lens is clean and clear"
        }
    }
}
