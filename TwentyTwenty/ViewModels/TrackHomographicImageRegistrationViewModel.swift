import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Track Homographic Image Registration model
@Observable
@MainActor
final class TrackHomographicImageRegistrationViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel
    var selectedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.documents, .objects]
    }

    // MARK: - Model-Specific State

    /// Requires two images for registration
    var requiresMultipleImages = true

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Processing

    func processImage() async {
        errorMessage = "This model requires two images for registration. Homographic registration computes a perspective transformation matrix to align images taken from different viewpoints or with different orientations."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
