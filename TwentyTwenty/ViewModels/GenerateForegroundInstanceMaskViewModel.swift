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
    var selectedImage: UIImage? {
        didSet {
            clearResults()
        }
    }
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .animals]
    }

    var supportsColorTinting: Bool {
        false
    }

    var overlayImage: UIImage? {
        renderedOverlay
    }

    // MARK: - Model-Specific State

    /// Generated foreground instance masks from the last analysis
    var foregroundInstances: [ForegroundInstance] = []

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
        foregroundInstances = []
        renderedOverlay = nil

        do {
            let ((instances, observation), tracker) = try await PerformanceTracker.measure {
                try await performForegroundInstanceMaskGeneration(on: image)
            }

            foregroundInstances = instances
            maskObservation = observation
            statistics = PerformanceStatistics(from: tracker)

            if foregroundInstances.isEmpty {
                errorMessage = "No foreground objects detected in the image"
            } else if let observation = maskObservation {
                renderedOverlay = await generateMaskOverlay(for: image, observation: observation)
            }
        } catch {
            errorMessage = "Mask generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        foregroundInstances = []
        maskObservation = nil
        renderedOverlay = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performForegroundInstanceMaskGeneration(on image: UIImage) async throws -> ([ForegroundInstance], InstanceMaskObservation?) {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GenerateForegroundInstanceMaskRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        if let observation = observation {
            return ([ForegroundInstance(from: observation)], observation)
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

// MARK: - Foreground Instance Model

/// Represents a foreground instance with segmentation mask
struct ForegroundInstance: Identifiable {
    let id = UUID()
    let confidence: Float
    let instanceCount: Int

    init(from observation: InstanceMaskObservation) {
        self.confidence = observation.confidence

        // Get all instances from the mask
        self.instanceCount = observation.allInstances.count
    }
}
