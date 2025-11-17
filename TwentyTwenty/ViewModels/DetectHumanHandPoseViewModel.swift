import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Human Hand Pose model
@Observable
@MainActor
final class DetectHumanHandPoseViewModel: BaseModelDetailViewModel {
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
        [.people]
    }

    var supportsColorTinting: Bool {
        false
    }

    var overlayImage: UIImage? {
        guard !detectedHands.isEmpty,
              let image = selectedImage else {
            return nil
        }
        return generateHandPoseOverlay(for: image)
    }

    // MARK: - Model-Specific State

    /// Detected hand poses from the last analysis
    var detectedHands: [HumanHandPose] = []

    /// Maximum number of hands to detect
    var maximumHandCount: Int = 2

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
        detectedHands = []

        do {
            let (hands, tracker) = try await PerformanceTracker.measure {
                try await performHandPoseDetection(on: image)
            }

            detectedHands = hands
            statistics = PerformanceStatistics(from: tracker)

            if detectedHands.isEmpty {
                errorMessage = "No hands detected in the image"
            }
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clearResults() {
        detectedHands = []
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Private Methods

    private func performHandPoseDetection(on image: UIImage) async throws -> [HumanHandPose] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = DetectHumanHandPoseRequest()
        // Note: maximumHandCount is not a property on modern API request
        // The request returns all detected hands

        let observations = try await request.perform(on: cgImage, orientation: nil)

        return observations.enumerated().compactMap { index, observation in
            HumanHandPose(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateHandPoseOverlay(for image: UIImage) -> UIImage {
        let poses = detectedHands.map { hand -> (joints: [CGPoint], groups: [OverlayRenderer.JointGroup]) in
            // Create a dictionary mapping joint names (rawValue strings) to indices
            var jointMap: [String: Int] = [:]
            let jointPoints = hand.joints.enumerated().map { index, joint -> CGPoint in
                jointMap[joint.name] = index
                return joint.position
            }

            // Define color scheme for each finger
            // Thumb: Red, Index: Orange, Middle: Yellow, Ring: Green, Little: Blue
            var jointGroups: [OverlayRenderer.JointGroup] = []

            // Thumb (red)
            let thumbConnections: [(String, String)] = [
                ("wrist", "thumbCMC"),
                ("thumbCMC", "thumbMP"),
                ("thumbMP", "thumbIP"),
                ("thumbIP", "thumbTip")
            ]
            jointGroups.append(createJointGroup(from: thumbConnections, color: UIColor.systemRed, jointMap: jointMap))

            // Index finger (orange)
            let indexConnections: [(String, String)] = [
                ("wrist", "indexMCP"),
                ("indexMCP", "indexPIP"),
                ("indexPIP", "indexDIP"),
                ("indexDIP", "indexTip")
            ]
            jointGroups.append(createJointGroup(from: indexConnections, color: UIColor.systemOrange, jointMap: jointMap))

            // Middle finger (yellow)
            let middleConnections: [(String, String)] = [
                ("wrist", "middleMCP"),
                ("middleMCP", "middlePIP"),
                ("middlePIP", "middleDIP"),
                ("middleDIP", "middleTip")
            ]
            jointGroups.append(createJointGroup(from: middleConnections, color: UIColor.systemYellow, jointMap: jointMap))

            // Ring finger (green)
            let ringConnections: [(String, String)] = [
                ("wrist", "ringMCP"),
                ("ringMCP", "ringPIP"),
                ("ringPIP", "ringDIP"),
                ("ringDIP", "ringTip")
            ]
            jointGroups.append(createJointGroup(from: ringConnections, color: UIColor.systemGreen, jointMap: jointMap))

            // Little finger (blue)
            let littleConnections: [(String, String)] = [
                ("wrist", "littleMCP"),
                ("littleMCP", "littlePIP"),
                ("littlePIP", "littleDIP"),
                ("littleDIP", "littleTip")
            ]
            jointGroups.append(createJointGroup(from: littleConnections, color: UIColor.systemBlue, jointMap: jointMap))

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

// MARK: - Human Hand Pose Model

/// Represents a detected human hand pose
struct HumanHandPose: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let chirality: HumanHandPoseObservation.Chirality?
    let joints: [HandJoint]

    init?(from observation: HumanHandPoseObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence
        self.chirality = observation.chirality

        var detectedJoints: [HandJoint] = []

        // Get all joints using the modern API
        let allJoints = observation.allJoints(in: nil)
        for (jointName, joint) in allJoints {
            if joint.confidence > 0.1 {
                detectedJoints.append(HandJoint(
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

    var chiralityDescription: String {
        guard let chirality = chirality else {
            return "Unknown Hand"
        }
        switch chirality {
        case .left:
            return "Left Hand"
        case .right:
            return "Right Hand"
        @unknown default:
            return "Unknown Hand"
        }
    }

    /// Number of fingers (excluding wrist)
    var fingerCount: Int {
        jointsByFinger.keys.filter { $0 != "Wrist" }.count
    }

    /// Joints grouped by finger
    var jointsByFinger: [String: [HandJoint]] {
        var categories: [String: [HandJoint]] = [
            "Wrist": [],
            "Thumb": [],
            "Index": [],
            "Middle": [],
            "Ring": [],
            "Little": []
        ]

        for joint in joints {
            let name = joint.name.lowercased()
            if name.contains("wrist") {
                categories["Wrist"]?.append(joint)
            } else if name.contains("thumb") {
                categories["Thumb"]?.append(joint)
            } else if name.contains("index") {
                categories["Index"]?.append(joint)
            } else if name.contains("middle") {
                categories["Middle"]?.append(joint)
            } else if name.contains("ring") {
                categories["Ring"]?.append(joint)
            } else if name.contains("little") {
                categories["Little"]?.append(joint)
            }
        }

        return categories.filter { !$0.value.isEmpty }
    }
}

/// Represents a single hand joint
struct HandJoint: Identifiable {
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
