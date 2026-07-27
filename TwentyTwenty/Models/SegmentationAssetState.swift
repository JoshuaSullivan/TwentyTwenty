import Foundation

/// Availability of the downloadable model backing iterative segmentation.
///
/// Mirrors Vision's `DownloadableAssetsRequestStatus` without depending on it, so views and
/// types below the iOS 27 availability boundary can refer to the state.
enum SegmentationAssetState: Equatable {
    /// The status has not been queried yet.
    case unknown

    /// The model is not on device and must be downloaded.
    case notReady

    /// A download is in progress.
    case downloading

    /// The model is on device and ready to use.
    case ready

    /// The status query or download failed, carrying a description of the failure.
    case failed(String)
}
