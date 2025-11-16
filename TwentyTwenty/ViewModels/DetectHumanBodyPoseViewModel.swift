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

        let request = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().compactMap { index, observation in
            HumanBodyPose(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generatePoseOverlay(for image: UIImage) -> UIImage {
        let poses = detectedPoses.map { pose -> (joints: [CGPoint], connections: [(Int, Int)]) in
            // Create a dictionary mapping joint names to indices
            var jointMap: [String: Int] = [:]
            let jointPoints = pose.joints.enumerated().map { index, joint -> CGPoint in
                // Normalize joint name: remove "_joint" suffix, underscores, and lowercase
                let normalizedName = joint.name
                    .lowercased()
                    .replacingOccurrences(of: "_joint", with: "")
                    .replacingOccurrences(of: "_", with: "")
                jointMap[normalizedName] = index
                return joint.position
            }

            // Define skeleton connections using actual Vision joint names
            var connections: [(Int, Int)] = []
            let connectionPairs: [(String, String)] = [
                // Head to face
                ("head", "lefteye"),
                ("head", "righteye"),
                ("lefteye", "leftear"),
                ("righteye", "rightear"),
                // Neck/shoulders (head connects down to shoulders)
                ("head", "leftshoulder1"),
                ("head", "rightshoulder1"),
                // Upper body
                ("leftshoulder1", "rightshoulder1"),
                // Spine (shoulders to hips)
                ("leftshoulder1", "leftupleg"),
                ("rightshoulder1", "rightupleg"),
                // Hips
                ("leftupleg", "rightupleg"),
                // Left arm
                ("leftshoulder1", "leftforearm"),
                ("leftforearm", "lefthand"),
                // Right arm
                ("rightshoulder1", "rightforearm"),
                ("rightforearm", "righthand"),
                // Left leg
                ("leftupleg", "leftleg"),
                ("leftleg", "leftfoot"),
                // Right leg
                ("rightupleg", "rightleg"),
                ("rightleg", "rightfoot")
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

// MARK: - Human Body Pose Model

/// Represents a detected human body pose
struct HumanBodyPose: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let joints: [BodyJoint]

    init?(from observation: VNHumanBodyPoseObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence

        var detectedJoints: [BodyJoint] = []

        // Get all recognized points using the modern API with type inference
        if let allPoints = try? observation.recognizedPoints(.all) {
            for (jointName, point) in allPoints {
                if point.confidence > 0.1 {
                    detectedJoints.append(BodyJoint(
                        name: jointName.rawValue.rawValue,
                        position: CGPoint(
                            x: point.location.x * imageSize.width,
                            y: (1 - point.location.y) * imageSize.height
                        ),
                        confidence: point.confidence
                    ))
                }
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
