import Foundation
import UIKit
import Vision
import Observation

/// ViewModel for the Track Translational Image Registration model
@Observable
@MainActor
final class TrackTranslationalImageRegistrationViewModel: BaseModelDetailViewModel {
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
        errorMessage = "This model requires two images for registration. Translational registration computes a simple x/y offset to align images that differ only by position, without rotation or scale changes."
        isProcessing = false
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
