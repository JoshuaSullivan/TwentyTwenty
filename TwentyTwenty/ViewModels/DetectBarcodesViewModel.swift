import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Barcodes model
@Observable
@MainActor
final class DetectBarcodesViewModel: BaseModelDetailViewModel {
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
        [.barcodes]
    }

    var overlayImage: UIImage? {
        guard !detectedBarcodes.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateBarcodeOverlay(for: image)
    }

    var overlayColor: UIColor = .systemGreen

    // MARK: - Model-Specific State

    /// Detected barcodes from the last analysis
    var detectedBarcodes: [DetectedBarcode] = []

    /// Selected barcode symbologies to detect
    var selectedSymbologies: Set<BarcodeSymbology> = [
        .qr,
        .ean13,
        .ean8,
        .upce,
        .code128,
        .code39,
        .code93,
        .pdf417
    ]

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
        detectedBarcodes = []

        do {
            let (barcodes, tracker) = try await PerformanceTracker.measure {
                try await performBarcodeDetection(on: image)
            }

            detectedBarcodes = barcodes
            statistics = PerformanceStatistics(from: tracker)

            if detectedBarcodes.isEmpty {
                errorMessage = "No barcodes detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedBarcodes = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performBarcodeDetection(on image: UIImage) async throws -> [DetectedBarcode] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        var request = DetectBarcodesRequest()
        request.symbologies = Array(selectedSymbologies)

        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.compactMap { observation in
            DetectedBarcode(from: observation, imageSize: image.size)
        }
    }

    private func generateBarcodeOverlay(for image: UIImage) -> UIImage {
        let rectangles = detectedBarcodes.map { barcode in
            let label = "\(barcode.symbologyName)\n\(barcode.payloadString ?? "N/A")"
            return (rect: barcode.boundingBox, label: label)
        }

        return OverlayRenderer.renderRectangles(rectangles, imageSize: image.size, color: overlayColor)
    }
}

// MARK: - Detected Barcode Model

/// Represents a detected barcode
struct DetectedBarcode: Identifiable {
    let id = UUID()
    let symbology: BarcodeSymbology
    let payloadString: String?
    let confidence: Float
    let boundingBox: CGRect

    init?(from observation: BarcodeObservation, imageSize: CGSize) {
        self.symbology = observation.symbology
        self.payloadString = observation.payloadString
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
    }

    var symbologyName: String {
        switch symbology {
        case .qr: return "QR Code"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upce: return "UPC-E"
        case .code128: return "Code 128"
        case .code39: return "Code 39"
        case .code93: return "Code 93"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .dataMatrix: return "Data Matrix"
        case .i2of5: return "I2of5"
        case .itf14: return "ITF-14"
        case .codabar: return "Codabar"
        case .gs1DataBar: return "GS1 DataBar"
        case .gs1DataBarExpanded: return "GS1 DataBar Expanded"
        case .gs1DataBarLimited: return "GS1 DataBar Limited"
        case .microQR: return "Micro QR"
        case .microPDF417: return "Micro PDF417"
        default: return "Unknown"
        }
    }
}

// MARK: - Vision Error

enum VisionError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        }
    }
}
