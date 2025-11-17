import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Generate Objectness-Based Saliency Image model
@Observable
@MainActor
final class GenerateObjectnessBasedSaliencyImageViewModel: BaseModelDetailViewModel {
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
        [.objects, .people, .nature]
    }

    var overlayImage: UIImage? {
        renderedOverlay
    }

    var overlayColor: UIColor = UIColor(hue: 0.5, saturation: 1.0, brightness: 1.0, alpha: 1.0) {
        didSet {
            // Regenerate overlay when color changes
            if let image = selectedImage, let heatMap = heatMapBuffer {
                Task {
                    renderedOverlay = await generateSaliencyOverlay(for: image, heatMap: heatMap)
                }
            }
        }
    }

    // MARK: - Model-Specific State

    /// Generated objectness saliency results from the last analysis
    var saliencyResults: [ObjectnessSaliency] = []

    /// Stored heat map pixel buffer for overlay generation
    private var heatMapBuffer: CVPixelBuffer?

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
        saliencyResults = []
        renderedOverlay = nil

        do {
            let ((results, heatMap), tracker) = try await PerformanceTracker.measure {
                try await performObjectnessSaliencyGeneration(on: image)
            }

            saliencyResults = results
            heatMapBuffer = heatMap
            statistics = PerformanceStatistics(from: tracker)

            if saliencyResults.isEmpty {
                errorMessage = "Failed to generate saliency map"
            } else if let heatMap = heatMapBuffer {
                renderedOverlay = await generateSaliencyOverlay(for: image, heatMap: heatMap)
            }
        } catch {
            errorMessage = "Saliency generation failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        saliencyResults = []
        heatMapBuffer = nil
        renderedOverlay = nil
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func generateSaliencyOverlay(for image: UIImage, heatMap: CVPixelBuffer) async -> UIImage? {
        return await OverlayRenderer.renderBitmapMask(heatMap, imageSize: image.size, tintColor: overlayColor)
    }

    private func performObjectnessSaliencyGeneration(on image: UIImage) async throws -> ([ObjectnessSaliency], CVPixelBuffer?) {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = GenerateObjectnessBasedSaliencyImageRequest()
        let observation = try await request.perform(on: cgImage, orientation: nil)

        let results = [ObjectnessSaliency(from: observation, index: 0, imageSize: image.size)]

        // Extract pixel buffer from observation using cgImage as intermediate
        var heatMapBuffer: CVPixelBuffer?
        if let cgImage = try? observation.heatMap.cgImage {
            // Convert CGImage back to CVPixelBuffer for mask rendering
            let width = cgImage.width
            let height = cgImage.height
            let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                              kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
            if let pixelBuffer = pixelBuffer {
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                      width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
                context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                heatMapBuffer = pixelBuffer
            }
        }

        return (results, heatMapBuffer)
    }
}

// MARK: - Objectness Saliency Model

/// Represents objectness-based saliency results
struct ObjectnessSaliency: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let salientObjects: [SalientObject]

    init(from observation: SaliencyImageObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Extract salient object regions
        self.salientObjects = observation.salientObjects.enumerated().map { objIndex, object in
            // Convert quadrilateral to bounding box
            let points = [
                object.topLeft,
                object.topRight,
                object.bottomRight,
                object.bottomLeft
            ]

            let minX = points.map { $0.x }.min() ?? 0
            let maxX = points.map { $0.x }.max() ?? 0
            let minY = points.map { $0.y }.min() ?? 0
            let maxY = points.map { $0.y }.max() ?? 0

            let boundingBox = CGRect(
                x: minX * imageSize.width,
                y: (1 - maxY) * imageSize.height,
                width: (maxX - minX) * imageSize.width,
                height: (maxY - minY) * imageSize.height
            )
            return SalientObject(index: objIndex, confidence: object.confidence, boundingBox: boundingBox)
        }
    }
}
