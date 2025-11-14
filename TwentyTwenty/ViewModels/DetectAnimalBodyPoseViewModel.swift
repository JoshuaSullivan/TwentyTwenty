import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Animal Body Pose model
@Observable
@MainActor
final class DetectAnimalBodyPoseViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.animals]
    }

    // MARK: - Model-Specific State

    /// Detected animal poses from the last analysis
    var detectedPoses: [AnimalBodyPose] = []

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
        detectedPoses = []

        do {
            let (poses, tracker) = try await PerformanceTracker.measure {
                try await performAnimalPoseDetection(on: image)
            }

            detectedPoses = poses
            statistics = PerformanceStatistics(from: tracker)

            if detectedPoses.isEmpty {
                errorMessage = "No animals (cats or dogs) detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedPoses = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performAnimalPoseDetection(on image: UIImage) async throws -> [AnimalBodyPose] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectAnimalBodyPoseRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().compactMap { index, observation in
            AnimalBodyPose(from: observation, index: index, imageSize: image.size)
        }
    }
}

// MARK: - Animal Body Pose Model

/// Represents a detected animal body pose
struct AnimalBodyPose: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let joints: [AnimalJoint]

    init?(from observation: VNAnimalBodyPoseObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        var detectedJoints: [AnimalJoint] = []

        // Define all animal joint types we want to detect
        let jointTypes: [VNAnimalBodyPoseObservation.JointName] = [
            .leftEarTop, .rightEarTop,
            .leftEarMiddle, .rightEarMiddle,
            .leftEarBottom, .rightEarBottom,
            .leftEye, .rightEye,
            .nose,
            .neck,
            .leftFrontElbow, .rightFrontElbow,
            .leftFrontKnee, .rightFrontKnee,
            .leftFrontPaw, .rightFrontPaw,
            .leftBackElbow, .rightBackElbow,
            .leftBackKnee, .rightBackKnee,
            .leftBackPaw, .rightBackPaw,
            .tailTop, .tailMiddle, .tailBottom
        ]

        for jointType in jointTypes {
            if let point = try? observation.recognizedPoint(jointType),
               point.confidence > 0.1 {
                detectedJoints.append(AnimalJoint(
                    name: jointType.rawValue.rawValue,
                    position: CGPoint(
                        x: point.location.x * imageSize.width,
                        y: (1 - point.location.y) * imageSize.height
                    ),
                    confidence: point.confidence
                ))
            }
        }

        self.joints = detectedJoints

        // Only return if we detected at least some joints
        guard !detectedJoints.isEmpty else {
            return nil
        }
    }

    /// Joints grouped by body part
    var jointsByCategory: [String: [AnimalJoint]] {
        var categories: [String: [AnimalJoint]] = [
            "Head": [],
            "Body": [],
            "Front Legs": [],
            "Back Legs": [],
            "Tail": []
        ]

        for joint in joints {
            let name = joint.name.lowercased()
            if name.contains("ear") || name.contains("eye") || name.contains("nose") {
                categories["Head"]?.append(joint)
            } else if name.contains("neck") {
                categories["Body"]?.append(joint)
            } else if name.contains("front") {
                categories["Front Legs"]?.append(joint)
            } else if name.contains("back") {
                categories["Back Legs"]?.append(joint)
            } else if name.contains("tail") {
                categories["Tail"]?.append(joint)
            }
        }

        return categories.filter { !$0.value.isEmpty }
    }
}

/// Represents a single animal joint
struct AnimalJoint: Identifiable {
    let id = UUID()
    let name: String
    let position: CGPoint
    let confidence: Float

    /// Display name for the joint
    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "animal ", with: "")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
