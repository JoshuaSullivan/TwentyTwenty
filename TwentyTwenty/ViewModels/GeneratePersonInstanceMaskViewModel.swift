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
    var selectedImage: UIImage? {
        didSet {
            clearResults()
        }
    }
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.people]
    }

    var supportsColorTinting: Bool {
        false
    }

    var overlayImage: UIImage? {
        renderedOverlay
    }

    // MARK: - Model-Specific State

    /// Generated person instance masks from the last analysis
    var personInstances: [PersonInstance] = []

    /// Stored mask observation for overlay generation
    private var maskObservation: InstanceMaskObservation?

    /// Pre-rendered overlay image
    private var renderedOverlay: UIImage?

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
        renderedOverlay = nil

        do {
            let ((instances, observation), tracker) = try await PerformanceTracker.measure {
                try await performPersonInstanceMaskGeneration(on: image)
            }

            personInstances = instances
            maskObservation = observation
            statistics = PerformanceStatistics(from: tracker)

            if personInstances.isEmpty {
                errorMessage = "No people detected in the image"
            } else if let observation = maskObservation {
                renderedOverlay = await generateMaskOverlay(for: image, observation: observation)
            }
        } catch {
            errorMessage = "Mask generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        personInstances = []
        maskObservation = nil
        renderedOverlay = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performPersonInstanceMaskGeneration(on image: UIImage) async throws -> ([PersonInstance], InstanceMaskObservation?) {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GeneratePersonInstanceMaskRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        if let observation = observation {
            return ([PersonInstance(from: observation)], observation)
        } else {
            return ([], nil)
        }
    }

    private func generateMaskOverlay(for image: UIImage, observation: InstanceMaskObservation) async -> UIImage {
        let instances = Array(observation.allInstances)
        let instanceCount = instances.count

        // Generate all mask images asynchronously first
        var maskImages: [UIImage] = []
        for (index, instanceIndex) in instances.enumerated() {
            let hue = CGFloat(index) / CGFloat(max(instanceCount, 1))
            let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

            if let maskBuffer = try? observation.generateMask(for: IndexSet(integer: instanceIndex)),
               let maskImage = await OverlayRenderer.renderBitmapMask(maskBuffer, imageSize: image.size, tintColor: color, flipVertically: true) {
                maskImages.append(maskImage)
            }
        }

        // Composite all mask images together
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            let ctx = context.cgContext
            for maskImage in maskImages {
                if let cgImage = maskImage.cgImage {
                    ctx.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
                }
            }
        }
    }
}

// MARK: - Person Instance Model

/// Represents a person instance with segmentation mask
struct PersonInstance: Identifiable {
    let id = UUID()
    let confidence: Float
    let instanceCount: Int

    init(from observation: InstanceMaskObservation) {
        self.confidence = observation.confidence

        // Get all instances from the mask
        self.instanceCount = observation.allInstances.count
    }
}
