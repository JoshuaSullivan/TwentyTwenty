import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Track Rectangle model
@Observable
@MainActor
final class TrackRectangleViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .documents]
    }

    // MARK: - Model-Specific State

    /// Tracking requires video input
    var requiresVideo = true

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Processing

    func processImage() async {
        errorMessage = "This model requires video input. Rectangle tracking follows rectangular regions across multiple frames, maintaining perspective as the rectangle moves, rotates, or changes scale."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
