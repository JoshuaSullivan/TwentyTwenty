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

    var overlayImage: UIImage? {
        guard !detectedFaces.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateLandmarksOverlay(for: image)
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

    private func generateLandmarksOverlay(for image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            let ctx = context.cgContext

            for face in detectedFaces {
                guard let landmarksData = face.landmarksData else { continue }

                // Render landmarks for this face
                let landmarkImage = OverlayRenderer.renderFaceLandmarks(
                    landmarksData,
                    boundingBox: face.boundingBox,
                    imageSize: image.size
                )

                // Composite the landmark image
                if let cgImage = landmarkImage.cgImage {
                    ctx.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
                }
            }
        }
    }

    private func performFaceLandmarksDetection(on image: UIImage) async throws -> [FaceWithLandmarks] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectFaceLandmarksRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().map { index, observation in
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
    let landmarksData: FaceObservation.Landmarks2D?

    init(from observation: FaceObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        // Convert normalized coordinates to image coordinates
        self.boundingBox = observation.boundingBox.toImageCoordinates(imageSize)

        self.landmarks = FaceLandmarks(from: observation.landmarks)
        self.landmarksData = observation.landmarks
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

    init(from landmarks: FaceObservation.Landmarks2D?) {
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

        self.hasLeftEye = !landmarks.leftEye.points.isEmpty
        self.hasRightEye = !landmarks.rightEye.points.isEmpty
        self.hasNose = !landmarks.nose.points.isEmpty
        self.hasMouth = !landmarks.outerLips.points.isEmpty
        self.hasFaceContour = !landmarks.faceContour.points.isEmpty
        self.hasLeftEyebrow = !landmarks.leftEyebrow.points.isEmpty
        self.hasRightEyebrow = !landmarks.rightEyebrow.points.isEmpty

        var count = 0
        count += landmarks.leftEye.points.count
        count += landmarks.rightEye.points.count
        count += landmarks.nose.points.count
        count += landmarks.outerLips.points.count
        count += landmarks.innerLips.points.count
        count += landmarks.faceContour.points.count
        count += landmarks.leftEyebrow.points.count
        count += landmarks.rightEyebrow.points.count
        self.totalPointsCount = count
    }
}
