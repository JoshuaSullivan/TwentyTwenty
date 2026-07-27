import SwiftUI

/// Placeholder shown when a Vision model can't be run.
///
/// The app lists models whose minimum iOS version exceeds its deployment target, and it also
/// builds against SDKs older than some of those models require. The router falls back to this
/// view rather than hiding the model, so the gallery still documents the full Vision API surface.
struct ModelUnavailableView: View {
    /// Why the model can't be run.
    enum Reason {
        /// The device is running an older iOS than the model requires.
        case deviceOSTooOld

        /// The app was compiled against an SDK that doesn't declare the model's API.
        ///
        /// Distinct from ``deviceOSTooOld``: the device may well be new enough, but the
        /// binary has no code for this model because the SDK it was built with predates it.
        case buildSDKTooOld
    }

    /// The model that cannot be run.
    let model: VisionModel

    /// Why it cannot be run. Determines the guidance shown to the user.
    let reason: Reason

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedVersion: String {
        model.minimumIOSVersion.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var title: String {
        switch reason {
        case .deviceOSTooOld: "Requires iOS \(formattedVersion)"
        case .buildSDKTooOld: "Not Included in This Build"
        }
    }

    private var message: String {
        switch reason {
        case .deviceOSTooOld:
            "\(model.name) uses Vision API that isn't available on this version of iOS. Update your device to try it."
        case .buildSDKTooOld:
            "\(model.name) uses Vision API from the iOS \(formattedVersion) SDK. This copy of the app was built with an older Xcode, so the model wasn't compiled in. Rebuild with Xcode \(formattedVersion) or newer to try it."
        }
    }
}

// MARK: - Preview

#Preview("Device OS too old") {
    NavigationStack {
        ModelUnavailableView(model: .iterativeSegmentationPreview, reason: .deviceOSTooOld)
    }
}

#Preview("Build SDK too old") {
    NavigationStack {
        ModelUnavailableView(model: .iterativeSegmentationPreview, reason: .buildSDKTooOld)
    }
}

private extension VisionModel {
    static let iterativeSegmentationPreview = VisionModel(
        id: "generate-iterative-segmentation",
        name: "Generate Iterative Segmentation",
        minimumIOSVersion: 27.0,
        description: "Segments an object from a seed point, refined by taps.",
        category: .generation,
        requestType: .generateIterativeSegmentation
    )
}
