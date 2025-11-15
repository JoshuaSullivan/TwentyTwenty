import SwiftUI
import PhotosUI

/// Reusable view for selecting images from bundled assets, camera, or photo library
struct ImageSelectionView: View {
    /// Binding to the currently selected image
    @Binding var selectedImage: UIImage?

    /// Optional filter for recommended bundled images based on content type
    let recommendedContentTypes: Set<ImageContentType>

    /// Optional overlay image to composite on top
    let overlayImage: UIImage?

    /// State for overlay display
    @State private var showOverlay = true
    @State private var overlayOpacity = 0.7
    @State private var overlayTint = Color.green

    /// State for presenting image pickers
    @State private var showingBundledImagePicker = false
    @State private var showingPhotoLibraryPicker = false
    @State private var showingCameraPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    init(
        selectedImage: Binding<UIImage?>,
        recommendedContentTypes: Set<ImageContentType> = [],
        overlayImage: UIImage? = nil
    ) {
        self._selectedImage = selectedImage
        self.recommendedContentTypes = recommendedContentTypes
        self.overlayImage = overlayImage
    }

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Selected Image Display

            if let image = selectedImage {
                VStack(spacing: 12) {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()

                        if showOverlay, let overlay = overlayImage {
                            Image(uiImage: overlay)
                                .resizable()
                                .scaledToFit()
                                .colorMultiply(overlayTint)
                                .opacity(overlayOpacity)
                        }
                    }
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                    .accessibilityLabel("Selected image for analysis")

                    if overlayImage != nil {
                        overlayControls
                    }
                }
            } else {
                placeholderView
            }

            // MARK: - Image Source Buttons

            HStack(spacing: 16) {
                ImageSourceButton(
                    icon: "photo.stack",
                    label: "Samples",
                    accessibilityLabel: "Select from bundled sample images"
                ) {
                    showingBundledImagePicker = true
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    ImageSourceButtonLabel(icon: "photo.on.rectangle", label: "Library")
                }
                .buttonStyle(.bordered)
                .onChange(of: selectedPhotoItem) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }
                .accessibilityLabel("Select from photo library")

                ImageSourceButton(
                    icon: "camera",
                    label: "Camera",
                    accessibilityLabel: "Take photo with camera"
                ) {
                    showingCameraPicker = true
                }
            }
        }
        .sheet(isPresented: $showingBundledImagePicker) {
            BundledImagePickerView(
                selectedImage: $selectedImage,
                recommendedContentTypes: recommendedContentTypes
            )
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPickerRepresentable(selectedImage: $selectedImage, dismiss: dismiss)
                .ignoresSafeArea()
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Select an image to analyze")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Choose from bundled samples, your photo library, or take a new photo")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("No image selected. Use buttons below to select an image")
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Show Overlay", isOn: $showOverlay)
                    .font(.subheadline)
                Spacer()
            }

            if showOverlay {
                VStack(spacing: 8) {
                    HStack {
                        Text("Opacity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $overlayOpacity, in: 0...1)
                        Text("\(Int(overlayOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }

                    HStack {
                        Text("Tint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ColorPicker("Overlay Color", selection: $overlayTint)
                            .labelsHidden()
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Bundled Image Picker

/// Sheet view for selecting from bundled sample images
struct BundledImagePickerView: View {
    @Binding var selectedImage: UIImage?
    let recommendedContentTypes: Set<ImageContentType>

    @Environment(\.dismiss) private var dismiss

    private var availableImages: [BundledImage] {
        if recommendedContentTypes.isEmpty {
            return BundledImageRegistry.allImages
        } else {
            return BundledImageRegistry.images(containing: recommendedContentTypes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(availableImages) { bundledImage in
                        BundledImageCard(bundledImage: bundledImage) {
                            if let image = ImageManager.loadImage(bundledImage) {
                                selectedImage = image
                                dismiss()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sample Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bundled Image Card

/// Card displaying a bundled image option
struct BundledImageCard: View {
    let bundledImage: BundledImage
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Image preview (or placeholder)
                if ImageManager.imageExists(bundledImage) {
                    ImageManager.loadSwiftUIImage(bundledImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bundledImage.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(bundledImage.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bundledImage.name): \(bundledImage.description)")
    }
}

// MARK: - Image Source Button

/// Reusable button for image source selection with icon and label
struct ImageSourceButton: View {
    let icon: String
    let label: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ImageSourceButtonLabel(icon: icon, label: label)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Label for image source buttons (icon above text)
struct ImageSourceButtonLabel: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(label)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ImageSelectionView(
        selectedImage: .constant(nil),
        recommendedContentTypes: [.people, .text]
    )
    .padding()
}
