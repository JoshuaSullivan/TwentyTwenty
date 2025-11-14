import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Face Landmarks model
@Observable
@MainActor
final class DetectFaceLandmarksViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.people]
    }

    // MARK: - Model-Specific State

    /// Detected faces with landmarks from the last analysis
    var detectedFaces: [FaceWithLandmarks] = []

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
                try await performFaceLandmarksDetection(on: image)
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

    private func performFaceLandmarksDetection(on image: UIImage) async throws -> [FaceWithLandmarks] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectFaceLandmarksRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().map { index, observation in
            FaceWithLandmarks(from: observation, index: index, imageSize: image.size)
        }
    }
}

// MARK: - Face With Landmarks Model

/// Represents a detected face with landmarks
struct FaceWithLandmarks: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let boundingBox: CGRect
    let landmarks: FaceLandmarks

    init(from observation: VNFaceObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        let box = observation.boundingBox
        self.boundingBox = CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )

        self.landmarks = FaceLandmarks(from: observation.landmarks)
    }
}

/// Represents face landmarks
struct FaceLandmarks {
    let hasLeftEye: Bool
    let hasRightEye: Bool
    let hasNose: Bool
    let hasMouth: Bool
    let hasFaceContour: Bool
    let hasLeftEyebrow: Bool
    let hasRightEyebrow: Bool

    let totalPointsCount: Int

    init(from landmarks: VNFaceLandmarks2D?) {
        guard let landmarks = landmarks else {
            self.hasLeftEye = false
            self.hasRightEye = false
            self.hasNose = false
            self.hasMouth = false
            self.hasFaceContour = false
            self.hasLeftEyebrow = false
            self.hasRightEyebrow = false
            self.totalPointsCount = 0
            return
        }

        self.hasLeftEye = landmarks.leftEye != nil
        self.hasRightEye = landmarks.rightEye != nil
        self.hasNose = landmarks.nose != nil
        self.hasMouth = landmarks.outerLips != nil
        self.hasFaceContour = landmarks.faceContour != nil
        self.hasLeftEyebrow = landmarks.leftEyebrow != nil
        self.hasRightEyebrow = landmarks.rightEyebrow != nil

        var count = 0
        count += landmarks.leftEye?.pointCount ?? 0
        count += landmarks.rightEye?.pointCount ?? 0
        count += landmarks.nose?.pointCount ?? 0
        count += landmarks.outerLips?.pointCount ?? 0
        count += landmarks.innerLips?.pointCount ?? 0
        count += landmarks.faceContour?.pointCount ?? 0
        count += landmarks.leftEyebrow?.pointCount ?? 0
        count += landmarks.rightEyebrow?.pointCount ?? 0
        self.totalPointsCount = count
    }
}
