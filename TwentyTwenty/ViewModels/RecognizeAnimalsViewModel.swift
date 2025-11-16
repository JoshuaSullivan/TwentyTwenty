import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Recognize Animals model
@Observable
@MainActor
final class RecognizeAnimalsViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.animals]
    }

    var overlayImage: UIImage? {
        guard !recognizedAnimals.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateAnimalOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Recognized animals from the last analysis
    var recognizedAnimals: [RecognizedAnimal] = []

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
        recognizedAnimals = []

        do {
            let (animals, tracker) = try await PerformanceTracker.measure {
                try await performAnimalRecognition(on: image)
            }

            recognizedAnimals = animals
            statistics = PerformanceStatistics(from: tracker)

            if recognizedAnimals.isEmpty {
                errorMessage = "No animals recognized in the image"
            }
        } catch {
            errorMessage = "Recognition failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        recognizedAnimals = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performAnimalRecognition(on image: UIImage) async throws -> [RecognizedAnimal] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = RecognizeAnimalsRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().map { index, observation in
            RecognizedAnimal(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateAnimalOverlay(for image: UIImage) -> UIImage {
        let rectangles = recognizedAnimals.map { animal in
            let label = String(format: "%@ (%.0f%%)", animal.topLabel, animal.confidence * 100)
            return (rect: animal.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size)
    }
}

// MARK: - Recognized Animal Model

/// Represents a recognized animal
struct RecognizedAnimal: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect
    let labels: [AnimalLabel]

    init(from observation: RecognizedObjectObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize)

        // Extract labels from the observation
        self.labels = observation.labels.map { label in
            AnimalLabel(identifier: label.identifier, confidence: label.confidence)
        }.sorted { $0.confidence > $1.confidence }
    }

    /// Top recognized animal type
    var topLabel: String {
        labels.first?.displayName ?? "Unknown"
    }
}

/// Represents an animal classification label
struct AnimalLabel: Identifiable {
    let id = UUID()
    let identifier: String
    let confidence: Float

    /// Display name for the label
    var displayName: String {
        identifier.capitalized
    }
}
