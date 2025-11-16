import Foundation
import UIKit

/// Represents the source of an image for Vision model processing
enum ImageSource {
    /// Image bundled with the app
    case bundled(BundledImage)

    /// Image from the device camera
    case camera

    /// Image from the device photo library
    case photoLibrary
}

/// Represents a bundled sample image
struct BundledImage: Identifiable, Hashable {
    /// Unique identifier
    let id: String

    /// Display name of the image
    let name: String

    /// Name of the image asset in Assets.xcassets
    let assetName: String

    /// Brief description of what the image contains
    let description: String

    /// Categories of content in the image (for filtering appropriate models)
    let contentTypes: Set<ImageContentType>
}

/// Types of content that might be in an image
enum ImageContentType: String, CaseIterable {
    case people
    case animals
    case text
    case barcodes
    case documents
    case nature
    case objects
    case architecture
}

/// Registry of all bundled sample images
struct BundledImageRegistry {
    /// All available bundled images
    static let allImages: [BundledImage] = [
        BundledImage(
            id: "sample-people",
            name: "People",
            assetName: "sample-people",
            description: "Group of people for face and body detection",
            contentTypes: [.people]
        ),
        BundledImage(
            id: "sample-hand",
            name: "Hand",
            assetName: "sample-hand",
            description: "Hand for hand pose detection",
            contentTypes: [.people]
        ),
        BundledImage(
            id: "sample-animal",
            name: "Animal",
            assetName: "sample-animal",
            description: "Animal for pose detection",
            contentTypes: [.animals]
        ),
        BundledImage(
            id: "sample-text",
            name: "Text Document",
            assetName: "sample-text",
            description: "Document with text for OCR",
            contentTypes: [.text, .documents]
        ),
        BundledImage(
            id: "sample-barcode",
            name: "Barcode",
            assetName: "sample-barcode",
            description: "QR code and barcodes",
            contentTypes: [.barcodes]
        ),
        BundledImage(
            id: "sample-nature",
            name: "Nature Scene",
            assetName: "sample-nature",
            description: "Natural landscape for classification",
            contentTypes: [.nature, .objects]
        ),
        BundledImage(
            id: "sample-architecture",
            name: "Architecture",
            assetName: "sample-architecture",
            description: "Building with geometric shapes",
            contentTypes: [.architecture, .objects]
        ),
    ]

    /// Returns images containing specific content types
    /// - Parameter contentTypes: Set of content types to filter by
    /// - Returns: Array of images containing any of the specified content types
    static func images(containing contentTypes: Set<ImageContentType>) -> [BundledImage] {
        guard !contentTypes.isEmpty else { return allImages }
        return allImages.filter { !$0.contentTypes.isDisjoint(with: contentTypes) }
    }
}
