import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Track Object model
@Observable
@MainActor
final class TrackObjectViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people]
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
        errorMessage = "This model requires video input. Object tracking analyzes motion across multiple frames to follow objects as they move through a scene. For demonstration purposes, this feature would need access to video data or a sequence of frames."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
