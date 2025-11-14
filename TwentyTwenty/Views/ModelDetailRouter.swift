import SwiftUI

/// Routes to the appropriate model detail view based on the Vision model
struct ModelDetailRouter: View {
    let model: VisionModel

    var body: some View {
        switch model.requestType {
        case .detectBarcodes:
            DetectBarcodesView(model: model)

        case .detectFaceRectangles:
            DetectFaceRectanglesView(model: model)

        case .recognizeText:
            RecognizeTextView(model: model)

        case .classifyImage:
            ClassifyImageView(model: model)

        case .detectRectangles:
            DetectRectanglesView(model: model)

        case .calculateImageAestheticsScores:
            CalculateImageAestheticsScoresView(model: model)

        case .detectHorizon:
            DetectHorizonView(model: model)

        case .detectFaceLandmarks:
            DetectFaceLandmarksView(model: model)

        case .detectFaceCaptureQuality:
            DetectFaceCaptureQualityView(model: model)

        case .detectHumanBodyPose:
            DetectHumanBodyPoseView(model: model)

        case .detectHumanRectangles:
            DetectHumanRectanglesView(model: model)

        case .detectAnimalBodyPose:
            DetectAnimalBodyPoseView(model: model)

        case .recognizeAnimals:
            RecognizeAnimalsView(model: model)

        case .detectTextRectangles:
            DetectTextRectanglesView(model: model)

        case .detectDocumentSegmentation:
            DetectDocumentSegmentationView(model: model)

        case .detectContours:
            DetectContoursView(model: model)

        case .detectHumanBodyPose3D:
            DetectHumanBodyPose3DView(model: model)

        case .generatePersonInstanceMask:
            GeneratePersonInstanceMaskView(model: model)

        case .generateForegroundInstanceMask:
            GenerateForegroundInstanceMaskView(model: model)

        case .generatePersonSegmentation:
            GeneratePersonSegmentationView(model: model)

        case .generateAttentionBasedSaliencyImage:
            GenerateAttentionBasedSaliencyImageView(model: model)

        case .generateObjectnessBasedSaliencyImage:
            GenerateObjectnessBasedSaliencyImageView(model: model)

        case .generateImageFeaturePrint:
            GenerateImageFeaturePrintView(model: model)

        case .trackObject:
            TrackObjectView(model: model)

        case .trackRectangle:
            TrackRectangleView(model: model)

        case .trackOpticalFlow:
            TrackOpticalFlowView(model: model)

        case .trackHomographicImageRegistration:
            TrackHomographicImageRegistrationView(model: model)

        case .trackTranslationalImageRegistration:
            TrackTranslationalImageRegistrationView(model: model)

        case .detectTrajectories:
            DetectTrajectoriesView(model: model)

        case .coreML:
            CoreMLView(model: model)
        }
    }
}
