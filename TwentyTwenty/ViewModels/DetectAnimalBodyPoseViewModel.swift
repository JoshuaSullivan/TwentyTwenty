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

    var overlayImage: UIImage? {
        guard !detectedPoses.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generatePoseOverlay(for: image)
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

        let request = DetectAnimalBodyPoseRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().compactMap { index, observation in
            AnimalBodyPose(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generatePoseOverlay(for image: UIImage) -> UIImage {
        let poses = detectedPoses.map { pose -> (joints: [CGPoint], connections: [(Int, Int)]) in
            // Create a dictionary mapping joint names (rawValue strings) to indices
            var jointMap: [String: Int] = [:]
            let jointPoints = pose.joints.enumerated().map { index, joint -> CGPoint in
                jointMap[joint.name] = index
                return joint.position
            }

            // Define skeleton connections using modern API enum rawValues
            var connections: [(Int, Int)] = []
            let connectionPairs: [(String, String)] = [
                // Ears (outer to inner)
                ("leftEarTop", "leftEarMiddle"),
                ("leftEarMiddle", "leftEarBottom"),
                ("rightEarTop", "rightEarMiddle"),
                ("rightEarMiddle", "rightEarBottom"),
                // Head - ears to eyes
                ("leftEarBottom", "leftEye"),
                ("rightEarBottom", "rightEye"),
                // Head - eyes to nose
                ("leftEye", "nose"),
                ("rightEye", "nose"),
                // Nose to neck
                ("nose", "neck"),
                // Front left leg
                ("neck", "leftFrontElbow"),
                ("leftFrontElbow", "leftFrontKnee"),
                ("leftFrontKnee", "leftFrontPaw"),
                // Front right leg
                ("neck", "rightFrontElbow"),
                ("rightFrontElbow", "rightFrontKnee"),
                ("rightFrontKnee", "rightFrontPaw"),
                // Back left leg
                ("neck", "leftBackElbow"),
                ("leftBackElbow", "leftBackKnee"),
                ("leftBackKnee", "leftBackPaw"),
                // Back right leg
                ("neck", "rightBackElbow"),
                ("rightBackElbow", "rightBackKnee"),
                ("rightBackKnee", "rightBackPaw"),
                // Tail
                ("neck", "tailTop"),
                ("tailTop", "tailMiddle"),
                ("tailMiddle", "tailBottom")
            ]

            for (from, to) in connectionPairs {
                if let fromIndex = jointMap[from],
                   let toIndex = jointMap[to] {
                    connections.append((fromIndex, toIndex))
                }
            }

            return (joints: jointPoints, connections: connections)
        }

        return OverlayRenderer.renderPoseSkeletons(poses, imageSize: image.size)
    }
}

// MARK: - Animal Body Pose Model

/// Represents a detected animal body pose
struct AnimalBodyPose: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let joints: [AnimalJoint]

    init?(from observation: AnimalBodyPoseObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        var detectedJoints: [AnimalJoint] = []

        // Get all joints using the modern API
        let allJoints = observation.allJoints(in: nil)
        for (jointName, joint) in allJoints {
            if joint.confidence > 0.1 {
                detectedJoints.append(AnimalJoint(
                    name: jointName.rawValue,
                    position: CGPoint(
                        x: joint.location.x * imageSize.width,
                        y: (1 - joint.location.y) * imageSize.height
                    ),
                    confidence: joint.confidence
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
