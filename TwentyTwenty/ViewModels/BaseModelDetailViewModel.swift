import Foundation
import UIKit
import AVFoundation
import Observation

/// Protocol that all model-specific detail ViewModels must conform to
@MainActor
protocol BaseModelDetailViewModel: AnyObject, Observable {
    /// The Vision model this ViewModel represents
    var model: VisionModel { get }

    /// Currently selected image for analysis
    var selectedImage: UIImage? { get set }

    /// Currently selected video for analysis (tracking models only)
    var selectedVideo: AVAsset? { get set }

    /// Whether this model requires video input instead of images
    var requiresVideo: Bool { get }

    /// Whether a Vision request is currently running
    var isProcessing: Bool { get set }

    /// Error message if the last request failed
    var errorMessage: String? { get set }

    /// Performance statistics from the last request
    var statistics: PerformanceStatistics? { get set }

    /// Recommended content types for this model
    var recommendedContentTypes: Set<ImageContentType> { get }

    /// Optional overlay image to display on top of the selected image
    var overlayImage: UIImage? { get }

    /// Color for overlay rendering (non-pose overlays)
    var overlayColor: UIColor { get set }

    /// Whether this model supports user-customizable color tinting of overlays
    var supportsColorTinting: Bool { get }

    /// Processes the currently selected image with the Vision model
    func processImage() async

    /// Processes the currently selected video with the Vision model (tracking models only)
    func processVideo() async

    /// Clears the current results and resets state
    func clearResults()
}

// MARK: - Default Implementations

extension BaseModelDetailViewModel {
    /// Default implementation returns empty set (all images suitable)
    var recommendedContentTypes: Set<ImageContentType> {
        []
    }

    /// Default implementation - no overlay
    var overlayImage: UIImage? {
        nil
    }

    /// Default implementation - green overlay color
    var overlayColor: UIColor {
        get { .systemGreen }
        set { }
    }

    /// Default implementation - supports color tinting
    var supportsColorTinting: Bool {
        true
    }

    /// Default implementation - most models use images, not video
    var requiresVideo: Bool {
        false
    }

    /// Default implementation - no video selected (non-tracking models don't need this)
    var selectedVideo: AVAsset? {
        get { nil }
        set { }
    }

    /// Default implementation - does nothing (override for tracking models)
    func processVideo() async {
        // No-op for non-video models
    }

    /// Default implementation clears error and statistics
    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}

// MARK: - Common ViewModel State

/// Common state and functionality for model detail ViewModels
@Observable
@MainActor
class BaseModelDetailViewModelImpl {
    /// The Vision model
    let model: VisionModel

    /// Currently selected image
    var selectedImage: UIImage?

    /// Currently selected video (tracking models only)
    var selectedVideo: AVAsset?

    /// Whether processing is in progress
    var isProcessing = false

    /// Error message
    var errorMessage: String?

    /// Performance statistics
    var statistics: PerformanceStatistics?

    init(model: VisionModel) {
        self.model = model
    }

    func clearResults() {
        errorMessage = nil
        statistics = nil
    }
}
