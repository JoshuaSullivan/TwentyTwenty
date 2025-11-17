import Foundation

/// Represents a Vision framework model available in the app
struct VisionModel: Identifiable, Hashable {
    /// Unique identifier for the model
    let id: String

    /// Display name of the model
    let name: String

    /// Minimum iOS version required to use this model
    let minimumIOSVersion: Double

    /// Brief description of what the model does
    let description: String

    /// Category of the model for organization
    let category: VisionModelCategory

    /// The type of Vision request this model uses
    let requestType: VisionRequestType
}

/// Categories for organizing Vision models
enum VisionModelCategory: String, CaseIterable, Identifiable {
    case detection = "Detection"
    case recognition = "Recognition"
    case generation = "Generation"
    case tracking = "Tracking"
    case classification = "Classification"
    case utility = "Utility"

    var id: String { rawValue }
}

/// Types of Vision requests available
enum VisionRequestType: String {
    // Detection requests
    case detectBarcodes
    case detectFaceRectangles
    case detectFaceLandmarks
    case detectFaceCaptureQuality
    case detectHumanBodyPose
    case detectHumanBodyPose3D
    case detectHumanHandPose
    case detectAnimalBodyPose
    case detectHumanRectangles
    case detectRectangles
    case detectTextRectangles
    case detectHorizon
    case detectContours
    case detectDocumentSegmentation
    case detectTrajectories

    // Recognition requests
    case recognizeText
    case recognizeAnimals

    // Classification requests
    case classifyImage

    // Generation requests
    case generateImageFeaturePrint
    case generatePersonInstanceMask
    case generateForegroundInstanceMask
    case generatePersonSegmentation
    case generateAttentionBasedSaliencyImage
    case generateObjectnessBasedSaliencyImage

    // Tracking requests
    case trackObject
    case trackRectangle
    case trackOpticalFlow
    case trackHomographicImageRegistration
    case trackTranslationalImageRegistration

    // Analysis requests
    case calculateImageAestheticsScores

    // Core ML integration
    case coreML
}
