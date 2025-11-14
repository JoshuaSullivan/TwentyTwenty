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

        // Placeholder for models not yet implemented
        default:
            ModelDetailPlaceholder(model: model)
        }
    }
}
