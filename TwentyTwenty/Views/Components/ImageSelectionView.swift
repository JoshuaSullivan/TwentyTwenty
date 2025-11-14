import SwiftUI
import PhotosUI

/// Reusable view for selecting images from bundled assets, camera, or photo library
struct ImageSelectionView: View {
    /// Binding to the currently selected image
    @Binding var selectedImage: UIImage?

    /// Optional filter for recommended bundled images based on content type
    let recommendedContentTypes: Set<ImageContentType>

    /// State for presenting image pickers
    @State private var showingBundledImagePicker = false
    @State private var showingPhotoLibraryPicker = false
    @State private var showingCameraPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(
        selectedImage: Binding<UIImage?>,
        recommendedContentTypes: Set<ImageContentType> = []
    ) {
        self._selectedImage = selectedImage
        self.recommendedContentTypes = recommendedContentTypes
    }

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Selected Image Display

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                    .accessibilityLabel("Selected image for analysis")
            } else {
                placeholderView
            }

            // MARK: - Image Source Buttons

            HStack(spacing: 12) {
                Button {
                    showingBundledImagePicker = true
                } label: {
                    Label("Bundled Images", systemImage: "photo.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Select from bundled sample images")

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
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

                Button {
                    showingCameraPicker = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Take photo with camera")
            }
        }
        .sheet(isPresented: $showingBundledImagePicker) {
            BundledImagePickerView(
                selectedImage: $selectedImage,
                recommendedContentTypes: recommendedContentTypes
            )
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPickerRepresentable(selectedImage: $selectedImage, dismiss: DismissAction())
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

// MARK: - Preview

#Preview {
    ImageSelectionView(
        selectedImage: .constant(nil),
        recommendedContentTypes: [.people, .text]
    )
    .padding()
}
