import Foundation

/// Central registry of all Vision framework models available in the app
struct VisionModelRegistry {
    /// All available Vision models
    static let allModels: [VisionModel] = [
        // MARK: - Detection Models

        VisionModel(
            id: "detect-barcodes",
            name: "Detect Barcodes",
            minimumIOSVersion: 11.0,
            description: "Detects and decodes various barcode symbologies including QR codes, EAN, UPC, and more",
            category: .detection,
            requestType: .detectBarcodes
        ),

        VisionModel(
            id: "detect-face-rectangles",
            name: "Detect Face Rectangles",
            minimumIOSVersion: 11.0,
            description: "Locates faces in images and returns bounding boxes",
            category: .detection,
            requestType: .detectFaceRectangles
        ),

        VisionModel(
            id: "detect-face-landmarks",
            name: "Detect Face Landmarks",
            minimumIOSVersion: 11.0,
            description: "Identifies facial features including eyes, nose, mouth, and facial contours",
            category: .detection,
            requestType: .detectFaceLandmarks
        ),

        VisionModel(
            id: "detect-face-capture-quality",
            name: "Detect Face Capture Quality",
            minimumIOSVersion: 13.0,
            description: "Evaluates the quality of face images for facial recognition purposes",
            category: .detection,
            requestType: .detectFaceCaptureQuality
        ),

        VisionModel(
            id: "detect-human-body-pose",
            name: "Detect Human Body Pose",
            minimumIOSVersion: 14.0,
            description: "Identifies body joint positions in 2D, optionally including hand poses",
            category: .detection,
            requestType: .detectHumanBodyPose
        ),

        VisionModel(
            id: "detect-human-body-pose-3d",
            name: "Detect Human Body Pose 3D",
            minimumIOSVersion: 17.0,
            description: "Identifies body joint positions in 3D space",
            category: .detection,
            requestType: .detectHumanBodyPose3D
        ),

        VisionModel(
            id: "detect-human-hand-pose",
            name: "Detect Human Hand Pose",
            minimumIOSVersion: 14.0,
            description: "Identifies hand joint positions including fingers and palm landmarks",
            category: .detection,
            requestType: .detectHumanHandPose
        ),

        VisionModel(
            id: "detect-animal-body-pose",
            name: "Detect Animal Body Pose",
            minimumIOSVersion: 17.0,
            description: "Identifies animal body joint positions for cats and dogs",
            category: .detection,
            requestType: .detectAnimalBodyPose
        ),

        VisionModel(
            id: "detect-human-rectangles",
            name: "Detect Human Rectangles",
            minimumIOSVersion: 15.0,
            description: "Locates human figures in images and returns bounding boxes",
            category: .detection,
            requestType: .detectHumanRectangles
        ),

        VisionModel(
            id: "detect-rectangles",
            name: "Detect Rectangles",
            minimumIOSVersion: 11.0,
            description: "Finds rectangular shapes in images, useful for document detection",
            category: .detection,
            requestType: .detectRectangles
        ),

        VisionModel(
            id: "detect-text-rectangles",
            name: "Detect Text Rectangles",
            minimumIOSVersion: 11.0,
            description: "Locates regions containing text without performing OCR",
            category: .detection,
            requestType: .detectTextRectangles
        ),

        VisionModel(
            id: "detect-horizon",
            name: "Detect Horizon",
            minimumIOSVersion: 12.0,
            description: "Identifies the horizon line angle in images",
            category: .detection,
            requestType: .detectHorizon
        ),

        VisionModel(
            id: "detect-contours",
            name: "Detect Contours",
            minimumIOSVersion: 14.0,
            description: "Finds edges and contours in images",
            category: .detection,
            requestType: .detectContours
        ),

        VisionModel(
            id: "detect-document-segmentation",
            name: "Detect Document Segmentation",
            minimumIOSVersion: 15.0,
            description: "Segments document regions in images",
            category: .detection,
            requestType: .detectDocumentSegmentation
        ),

        VisionModel(
            id: "detect-trajectories",
            name: "Detect Trajectories",
            minimumIOSVersion: 14.0,
            description: "Analyzes object motion paths across multiple frames",
            category: .detection,
            requestType: .detectTrajectories
        ),

        // MARK: - Recognition Models

        VisionModel(
            id: "recognize-text",
            name: "Recognize Text",
            minimumIOSVersion: 13.0,
            description: "Performs OCR to recognize text in 18+ languages",
            category: .recognition,
            requestType: .recognizeText
        ),

        VisionModel(
            id: "recognize-animals",
            name: "Recognize Animals",
            minimumIOSVersion: 17.0,
            description: "Identifies animal species in images",
            category: .recognition,
            requestType: .recognizeAnimals
        ),

        // MARK: - Classification Models

        VisionModel(
            id: "classify-image",
            name: "Classify Image",
            minimumIOSVersion: 11.0,
            description: "Categorizes images into approximately 5,000 different object classes",
            category: .classification,
            requestType: .classifyImage
        ),

        // MARK: - Generation Models

        VisionModel(
            id: "generate-image-feature-print",
            name: "Generate Image Feature Print",
            minimumIOSVersion: 13.0,
            description: "Creates a feature vector representation for image comparison and similarity",
            category: .generation,
            requestType: .generateImageFeaturePrint
        ),

        VisionModel(
            id: "generate-person-instance-mask",
            name: "Generate Person Instance Mask",
            minimumIOSVersion: 15.0,
            description: "Creates a segmentation mask for individual people in images",
            category: .generation,
            requestType: .generatePersonInstanceMask
        ),

        VisionModel(
            id: "generate-foreground-instance-mask",
            name: "Generate Foreground Instance Mask",
            minimumIOSVersion: 17.0,
            description: "Separates foreground objects from background",
            category: .generation,
            requestType: .generateForegroundInstanceMask
        ),

        VisionModel(
            id: "generate-person-segmentation",
            name: "Generate Person Segmentation",
            minimumIOSVersion: 15.0,
            description: "Segments people in images with pixel-level accuracy",
            category: .generation,
            requestType: .generatePersonSegmentation
        ),

        VisionModel(
            id: "generate-attention-based-saliency",
            name: "Generate Attention-Based Saliency",
            minimumIOSVersion: 13.0,
            description: "Highlights visually interesting regions that draw human attention",
            category: .generation,
            requestType: .generateAttentionBasedSaliencyImage
        ),

        VisionModel(
            id: "generate-objectness-based-saliency",
            name: "Generate Objectness-Based Saliency",
            minimumIOSVersion: 13.0,
            description: "Highlights regions likely to contain distinct objects",
            category: .generation,
            requestType: .generateObjectnessBasedSaliencyImage
        ),

        // MARK: - Tracking Models

        VisionModel(
            id: "track-object",
            name: "Track Object",
            minimumIOSVersion: 11.0,
            description: "Tracks objects across video frames",
            category: .tracking,
            requestType: .trackObject
        ),

        VisionModel(
            id: "track-rectangle",
            name: "Track Rectangle",
            minimumIOSVersion: 11.0,
            description: "Tracks rectangular regions across video frames",
            category: .tracking,
            requestType: .trackRectangle
        ),

        VisionModel(
            id: "track-optical-flow",
            name: "Track Optical Flow",
            minimumIOSVersion: 14.0,
            description: "Analyzes motion between consecutive frames",
            category: .tracking,
            requestType: .trackOpticalFlow
        ),

        VisionModel(
            id: "track-homographic-image-registration",
            name: "Track Homographic Image Registration",
            minimumIOSVersion: 13.0,
            description: "Aligns images using perspective transformations",
            category: .tracking,
            requestType: .trackHomographicImageRegistration
        ),

        VisionModel(
            id: "track-translational-image-registration",
            name: "Track Translational Image Registration",
            minimumIOSVersion: 11.0,
            description: "Aligns images using simple translation",
            category: .tracking,
            requestType: .trackTranslationalImageRegistration
        ),

        // MARK: - Analysis Models

        VisionModel(
            id: "calculate-image-aesthetics-scores",
            name: "Calculate Image Aesthetics Scores",
            minimumIOSVersion: 18.0,
            description: "Evaluates image quality, composition, lighting, and memorability",
            category: .classification,
            requestType: .calculateImageAestheticsScores
        ),

        // MARK: - Core ML Integration

        VisionModel(
            id: "core-ml-request",
            name: "Core ML Request",
            minimumIOSVersion: 11.0,
            description: "Integrates custom Core ML models with Vision pipeline",
            category: .classification,
            requestType: .coreML
        ),
    ]

    /// Returns all models that are available for a given minimum iOS version
    /// - Parameter minimumVersion: The minimum iOS version to filter by
    /// - Returns: Array of models available in that iOS version or later
    static func models(availableIn minimumVersion: Double?) -> [VisionModel] {
        guard let minimumVersion = minimumVersion else {
            return allModels
        }
        return allModels.filter { $0.minimumIOSVersion <= minimumVersion }
    }

    /// Returns unique iOS versions across all models, sorted
    static var availableIOSVersions: [Double] {
        let versions = Set(allModels.map { $0.minimumIOSVersion })
        return versions.sorted()
    }
}
