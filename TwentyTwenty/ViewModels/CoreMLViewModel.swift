import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Core ML Request model
@Observable
@MainActor
final class CoreMLViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .nature, .documents]
    }

    // MARK: - Model-Specific State

    /// Requires user-provided Core ML model
    var requiresUserModel = true

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Processing

    func processImage() async {
        errorMessage = "This feature requires a user-provided Core ML model file (.mlmodel or .mlmodelc). Core ML models can be trained using Create ML, imported from third-party sources, or downloaded from Apple's model gallery."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
