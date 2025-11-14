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
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.barcodes]
    }

    // MARK: - Model-Specific State

    /// Detected barcodes from the last analysis
    var detectedBarcodes: [DetectedBarcode] = []

    /// Selected barcode symbologies to detect
    var selectedSymbologies: Set<VNBarcodeSymbology> = [
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

        let request = VNDetectBarcodesRequest()
        request.symbologies = Array(selectedSymbologies)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.compactMap { observation in
            DetectedBarcode(from: observation, imageSize: image.size)
        }
    }
}

// MARK: - Detected Barcode Model

/// Represents a detected barcode
struct DetectedBarcode: Identifiable {
    let id = UUID()
    let symbology: VNBarcodeSymbology
    let payloadString: String?
    let confidence: Float
    let boundingBox: CGRect

    init?(from observation: VNBarcodeObservation, imageSize: CGSize) {
        self.symbology = observation.symbology
        self.payloadString = observation.payloadStringValue
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
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
