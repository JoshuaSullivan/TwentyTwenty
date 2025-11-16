import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Recognize Text model (OCR)
@Observable
@MainActor
final class RecognizeTextViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.text, .documents]
    }

    var overlayImage: UIImage? {
        guard !recognizedTexts.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateTextOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Recognized text observations from the last analysis
    var recognizedTexts: [RecognizedText] = []

    /// Recognition level (fast vs accurate)
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate

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
        recognizedTexts = []

        do {
            let (texts, tracker) = try await PerformanceTracker.measure {
                try await performTextRecognition(on: image)
            }

            recognizedTexts = texts
            statistics = PerformanceStatistics(from: tracker)

            if recognizedTexts.isEmpty {
                errorMessage = "No text detected in the image"
            }
        } catch {
            errorMessage = "Recognition failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        recognizedTexts = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Computed Properties

    /// All recognized text concatenated
    var fullText: String {
        recognizedTexts.map { $0.text }.joined(separator: "\n")
    }

    // MARK: - Private Methods

    private func generateTextOverlay(for image: UIImage) -> UIImage {
        let rectangles = recognizedTexts.map { text in
            // Truncate long text for labels
            let label = text.text.count > 20 ? String(text.text.prefix(17)) + "..." : text.text
            return (rect: text.boundingBox, label: label)
        }
        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }

    private func performTextRecognition(on image: UIImage) async throws -> [RecognizedText] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.compactMap { observation in
            RecognizedText(from: observation, imageSize: image.size)
        }
    }
}

// MARK: - Recognized Text Model

/// Represents recognized text
struct RecognizedText: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect

    init?(from observation: VNRecognizedTextObservation, imageSize: CGSize) {
        guard let topCandidate = observation.topCandidates(1).first else {
            return nil
        }

        self.text = topCandidate.string
        self.confidence = topCandidate.confidence

        // Convert normalized coordinates to image coordinates
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }
}
