import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Track Optical Flow model
@Observable
@MainActor
final class TrackOpticalFlowViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .people, .nature]
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
        errorMessage = "This model requires video input. Optical flow analyzes the pattern of motion between consecutive frames, generating a dense field of motion vectors that show how pixels move across the scene."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
