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
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.people]
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

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = maximumHandCount

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return []
        }

        return results.enumerated().compactMap { index, observation in
            HumanHandPose(from: observation, index: index, imageSize: image.size)
        }
    }

    private func generateHandPoseOverlay(for image: UIImage) -> UIImage {
        let poses = detectedHands.map { hand -> (joints: [CGPoint], connections: [(Int, Int)]) in
            // Create a dictionary mapping joint names to indices
            var jointMap: [String: Int] = [:]
            let jointPoints = hand.joints.enumerated().map { index, joint -> CGPoint in
                // Normalize joint name: remove "_joint" suffix, underscores, and lowercase
                let normalizedName = joint.name
                    .lowercased()
                    .replacingOccurrences(of: "_joint", with: "")
                    .replacingOccurrences(of: "_", with: "")
                jointMap[normalizedName] = index
                return joint.position
            }

            // Define skeleton connections for hands
            var connections: [(Int, Int)] = []
            let connectionPairs: [(String, String)] = [
                // Thumb
                ("wrist", "thumbcmc"),
                ("thumbcmc", "thumbmp"),
                ("thumbmp", "thumbip"),
                ("thumbip", "thumbtip"),
                // Index finger
                ("wrist", "indexmcp"),
                ("indexmcp", "indexpip"),
                ("indexpip", "indexdip"),
                ("indexdip", "indextip"),
                // Middle finger
                ("wrist", "middlemcp"),
                ("middlemcp", "middlepip"),
                ("middlepip", "middledip"),
                ("middledip", "middletip"),
                // Ring finger
                ("wrist", "ringmcp"),
                ("ringmcp", "ringpip"),
                ("ringpip", "ringdip"),
                ("ringdip", "ringtip"),
                // Little finger
                ("wrist", "littlemcp"),
                ("littlemcp", "littlepip"),
                ("littlepip", "littledip"),
                ("littledip", "littletip")
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

// MARK: - Human Hand Pose Model

/// Represents a detected human hand pose
struct HumanHandPose: Identifiable {
    let id = UUID()
    let index: Int
    let confidence: Float
    let chirality: VNChirality
    let joints: [HandJoint]

    init?(from observation: VNHumanHandPoseObservation, index: Int, imageSize: CGSize) {
        self.index = index
        self.confidence = observation.confidence
        self.chirality = observation.chirality

        var detectedJoints: [HandJoint] = []

        // Define all hand joint types we want to detect
        let jointTypes: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            // Thumb
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            // Index finger
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            // Middle finger
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            // Ring finger
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            // Little finger
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]

        for jointType in jointTypes {
            if let point = try? observation.recognizedPoint(jointType),
               point.confidence > 0.1 {
                detectedJoints.append(HandJoint(
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

    var chiralityDescription: String {
        switch chirality {
        case .left:
            return "Left Hand"
        case .right:
            return "Right Hand"
        @unknown default:
            return "Unknown Hand"
        }
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
