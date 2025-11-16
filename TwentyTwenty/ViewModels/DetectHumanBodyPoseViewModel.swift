import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Human Body Pose model
@Observable
@MainActor
final class DetectHumanBodyPoseViewModel: BaseModelDetailViewModel {
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
        guard !detectedPoses.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generatePoseOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected body poses from the last analysis
    var detectedPoses: [HumanBodyPose] = []

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
                try await performBodyPoseDetection(on: image)
            }

            detectedPoses = poses
            statistics = PerformanceStatistics(from: tracker)

            if detectedPoses.isEmpty {
                errorMessage = "No human bodies detected in the image"
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

    private func performBodyPoseDetection(on image: UIImage) async throws -> [HumanBodyPose] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectHumanBodyPoseRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().compactMap { index, observation in
            HumanBodyPose(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generatePoseOverlay(for image: UIImage) -> UIImage {
        let poses = detectedPoses.map { pose -> (joints: [CGPoint], groups: [OverlayRenderer.JointGroup]) in
            // Create a dictionary mapping joint names (rawValue strings) to indices
            var jointMap: [String: Int] = [:]
            let jointPoints = pose.joints.enumerated().map { index, joint -> CGPoint in
                jointMap[joint.name] = index
                return joint.position
            }

            // Define color scheme by body part
            // Head: Purple, Torso: Blue, Left Arm: Green, Right Arm: Cyan, Left Leg: Orange, Right Leg: Red
            var jointGroups: [OverlayRenderer.JointGroup] = []

            // Head/face (purple)
            let headConnections: [(String, String)] = [
                ("nose", "leftEye"),
                ("nose", "rightEye"),
                ("leftEye", "leftEar"),
                ("rightEye", "rightEar")
            ]
            jointGroups.append(createJointGroup(from: headConnections, color: UIColor.systemPurple, jointMap: jointMap))

            // Torso/spine (blue)
            let torsoConnections: [(String, String)] = [
                ("neck", "leftShoulder"),
                ("neck", "rightShoulder"),
                ("leftShoulder", "rightShoulder"),
                ("neck", "root"),
                ("root", "leftHip"),
                ("root", "rightHip"),
                ("leftHip", "rightHip")
            ]
            jointGroups.append(createJointGroup(from: torsoConnections, color: UIColor.systemBlue, jointMap: jointMap))

            // Left arm (green)
            let leftArmConnections: [(String, String)] = [
                ("leftShoulder", "leftElbow"),
                ("leftElbow", "leftWrist")
            ]
            jointGroups.append(createJointGroup(from: leftArmConnections, color: UIColor.systemGreen, jointMap: jointMap))

            // Right arm (cyan)
            let rightArmConnections: [(String, String)] = [
                ("rightShoulder", "rightElbow"),
                ("rightElbow", "rightWrist")
            ]
            jointGroups.append(createJointGroup(from: rightArmConnections, color: UIColor.systemCyan, jointMap: jointMap))

            // Left leg (orange)
            let leftLegConnections: [(String, String)] = [
                ("leftHip", "leftKnee"),
                ("leftKnee", "leftAnkle")
            ]
            jointGroups.append(createJointGroup(from: leftLegConnections, color: UIColor.systemOrange, jointMap: jointMap))

            // Right leg (red)
            let rightLegConnections: [(String, String)] = [
                ("rightHip", "rightKnee"),
                ("rightKnee", "rightAnkle")
            ]
            jointGroups.append(createJointGroup(from: rightLegConnections, color: UIColor.systemRed, jointMap: jointMap))

            return (joints: jointPoints, groups: jointGroups)
        }

        return OverlayRenderer.renderPoseSkeletons(poses, imageSize: image.size)
    }

    private func createJointGroup(from pairs: [(String, String)], color: UIColor, jointMap: [String: Int]) -> OverlayRenderer.JointGroup {
        var connections: [(Int, Int)] = []
        for (from, to) in pairs {
            if let fromIndex = jointMap[from],
               let toIndex = jointMap[to] {
                connections.append((fromIndex, toIndex))
            }
        }
        return OverlayRenderer.JointGroup(connections: connections, color: color)
    }
}

// MARK: - Human Body Pose Model

/// Represents a detected human body pose
struct HumanBodyPose: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let joints: [BodyJoint]

    init?(from observation: HumanBodyPoseObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        var detectedJoints: [BodyJoint] = []

        // Get all joints using the modern API
        let allJoints = observation.allJoints(in: nil)
        for (jointName, joint) in allJoints {
            if joint.confidence > 0.1 {
                detectedJoints.append(BodyJoint(
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
    var jointsByCategory: [String: [BodyJoint]] {
        var categories: [String: [BodyJoint]] = [
            "Head": [],
            "Torso": [],
            "Arms": [],
            "Legs": []
        ]

        for joint in joints {
            let name = joint.name.lowercased()
            if name.contains("eye") || name.contains("ear") || name.contains("nose") {
                categories["Head"]?.append(joint)
            } else if name.contains("shoulder") || name.contains("hip") {
                categories["Torso"]?.append(joint)
            } else if name.contains("elbow") || name.contains("wrist") {
                categories["Arms"]?.append(joint)
            } else if name.contains("knee") || name.contains("ankle") {
                categories["Legs"]?.append(joint)
            }
        }

        return categories.filter { !$0.value.isEmpty }
    }
}

/// Represents a single body joint
struct BodyJoint: Identifiable {
    let id = UUID()
    let name: String
    let position: CGPoint
    let confidence: Float

    /// Display name for the joint
    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
