import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Detect Trajectories model
@Observable
@MainActor
final class DetectTrajectoriesViewModel: BaseModelDetailViewModel {
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
        errorMessage = "This model requires video input. Trajectory detection analyzes object motion paths across multiple frames, identifying curved and complex movement patterns over time."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
