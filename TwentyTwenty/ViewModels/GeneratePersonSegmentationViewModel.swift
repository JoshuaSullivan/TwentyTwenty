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

    var overlayImage: UIImage? {
        renderedOverlay
    }

    var overlayColor: UIColor = UIColor(hue: 0.83, saturation: 1.0, brightness: 1.0, alpha: 1.0) {
        didSet {
            // Regenerate overlay when color changes
            if let image = selectedImage, let result = segmentationResult {
                Task {
                    renderedOverlay = await generateSegmentationOverlay(for: image, result: result)
                }
            }
        }
    }

    // MARK: - Model-Specific State

    /// Generated person segmentation result from the last analysis
    var segmentationResult: PersonSegmentation?

    /// Pre-rendered overlay image
    private var renderedOverlay: UIImage?

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
        renderedOverlay = nil

        do {
            let (result, tracker) = try await PerformanceTracker.measure {
                try await performPersonSegmentation(on: image)
            }

            segmentationResult = result
            statistics = PerformanceStatistics(from: tracker)

            if let result = segmentationResult {
                renderedOverlay = await generateSegmentationOverlay(for: image, result: result)
            } else {
                errorMessage = "No people detected in the image"
            }
        } catch {
            errorMessage = "Segmentation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        segmentationResult = nil
        renderedOverlay = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performPersonSegmentation(on image: UIImage) async throws -> PersonSegmentation? {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GeneratePersonSegmentationRequest()
        request.qualityLevel = qualityLevel

        let observation = try await request.perform(on: cgImage, orientation: nil)

        return PersonSegmentation(from: observation)
    }

    private func generateSegmentationOverlay(for image: UIImage, result: PersonSegmentation) async -> UIImage? {
        // Extract pixel buffer from observation using cgImage as intermediate
        guard let cgImage = try? result.observation.cgImage else {
            return nil
        }

        // Convert CGImage to CVPixelBuffer for mask rendering
        let width = cgImage.width
        let height = cgImage.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                          kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)

        guard let pixelBuffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                              width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        return await OverlayRenderer.renderBitmapMask(pixelBuffer, imageSize: image.size, tintColor: overlayColor)
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
