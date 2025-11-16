import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Face Rectangles model
@Observable
@MainActor
final class DetectFaceRectanglesViewModel: BaseModelDetailViewModel {
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
        guard !detectedFaces.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateFaceOverlay(for: image)
    }

    var overlayColor: UIColor = .systemGreen

    // MARK: - Model-Specific State

    /// Detected faces from the last analysis
    var detectedFaces: [DetectedFace] = []

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
        detectedFaces = []

        do {
            let (faces, tracker) = try await PerformanceTracker.measure {
                try await performFaceDetection(on: image)
            }

            detectedFaces = faces
            statistics = PerformanceStatistics(from: tracker)

            if detectedFaces.isEmpty {
                errorMessage = "No faces detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedFaces = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performFaceDetection(on image: UIImage) async throws -> [DetectedFace] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectFaceRectanglesRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().map { index, observation in
            DetectedFace(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateFaceOverlay(for image: UIImage) -> UIImage {
        let rectangles = detectedFaces.map { face in
            let label = String(format: "%.0f%%", face.confidence * 100)
            return (rect: face.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size, color: overlayColor)
    }
}

// MARK: - Detected Face Model

/// Represents a detected face
struct DetectedFace: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect

    init(from observation: FaceObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
    }
}
