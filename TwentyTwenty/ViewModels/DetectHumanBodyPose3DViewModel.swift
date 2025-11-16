import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Human Body Pose 3D model
@Observable
@MainActor
final class DetectHumanBodyPose3DViewModel: BaseModelDetailViewModel {
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

    /// Detected 3D body poses from the last analysis
    var detectedPoses: [HumanBodyPose3D] = []

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
                try await performBodyPose3DDetection(on: image)
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

    private func performBodyPose3DDetection(on image: UIImage) async throws -> [HumanBodyPose3D] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectHumanBodyPose3DRequest()
        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().compactMap { index, observation in
            HumanBodyPose3D(from: observation, index: index)
        }
    }
}

// MARK: - Human Body Pose 3D Model

/// Represents a detected human body pose in 3D
struct HumanBodyPose3D: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let joints: [BodyJoint3D]

    init?(from observation: HumanBodyPose3DObservation, index: Int) {
        self.index = index
        self.confidence = observation.confidence

        var detectedJoints: [BodyJoint3D] = []

        // Define all 3D body joint types
        let jointTypes: [HumanBodyPose3DObservation.JointName] = [
            .root,
            .spine, .centerShoulder, .centerHead, .topHead,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for jointType in jointTypes {
            if let point = try? observation.joint(for: jointType) {
                let pos = point.localPosition.columns.3
                if pos.x.isFinite && pos.y.isFinite && pos.z.isFinite {
                    detectedJoints.append(BodyJoint3D(
                        name: jointType.rawValue,
                        position: point.localPosition
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
    var jointsByCategory: [String: [BodyJoint3D]] {
        var categories: [String: [BodyJoint3D]] = [
            "Head & Spine": [],
            "Torso": [],
            "Arms": [],
            "Legs": []
        ]

        for joint in joints {
            let name = joint.name.lowercased()
            if name.contains("head") || name.contains("spine") || name.contains("root") {
                categories["Head & Spine"]?.append(joint)
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

/// Represents a single 3D body joint
struct BodyJoint3D: Identifiable {
    let id = UUID()
    let name: String
    let position: simd_float4x4

    /// Display name for the joint
    var displayName: String {
        name.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Extract approximate 3D coordinates (x, y, z) from the transformation matrix
    var coordinates: (x: Float, y: Float, z: Float) {
        (
            x: position.columns.3.x,
            y: position.columns.3.y,
            z: position.columns.3.z
        )
    }
}
