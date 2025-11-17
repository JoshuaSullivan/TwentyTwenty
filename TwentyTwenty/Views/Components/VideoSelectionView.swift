import SwiftUI
import AVFoundation
import PhotosUI

/// Reusable view for selecting videos from bundled assets
struct VideoSelectionView: View {
    /// Binding to the currently selected video
    @Binding var selectedVideo: AVAsset?

    /// Optional filter for recommended bundled videos based on content type
    let recommendedContentTypes: Set<ImageContentType>

    /// State for presenting video picker
    @State private var showingBundledVideoPicker = false

    /// State for photo library picker
    @State private var photoPickerItem: PhotosPickerItem?

    /// State for video metadata and thumbnail
    @State private var videoMetadata: VideoMetadata?
    @State private var videoThumbnail: UIImage?

    init(
        selectedVideo: Binding<AVAsset?>,
        recommendedContentTypes: Set<ImageContentType> = []
    ) {
        self._selectedVideo = selectedVideo
        self.recommendedContentTypes = recommendedContentTypes
    }

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Selected Video Display

            if selectedVideo != nil {
                VStack(spacing: 12) {
                    // Video thumbnail
                    if let thumbnail = videoThumbnail {
                        ZStack(alignment: .center) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 4)

                            // Play icon overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)
                                .shadow(radius: 8)
                        }
                        .accessibilityLabel("Selected video for analysis")
                    }

                    // Video metadata
                    if let metadata = videoMetadata {
                        HStack(spacing: 16) {
                            MetadataItem(icon: "clock", text: metadata.formattedDuration)
                            MetadataItem(icon: "aspectratio", text: metadata.formattedDimensions)
                            MetadataItem(icon: "speedometer", text: metadata.formattedFrameRate)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                placeholderView
            }

            // MARK: - Video Source Buttons

            HStack(spacing: 16) {
                VideoSourceButton(
                    icon: "photo.stack",
                    label: "Bundled",
                    accessibilityLabel: "Select from bundled sample videos"
                ) {
                    showingBundledVideoPicker = true
                }

                PhotosPicker(selection: $photoPickerItem, matching: .videos) {
                    VideoSourceButtonLabel(icon: "photo.on.rectangle", label: "Photo Library")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Select video from photo library")
            }

            // MARK: - Bundled Video Picker Sheet
            .sheet(isPresented: $showingBundledVideoPicker) {
                BundledVideoPickerView(
                    recommendedContentTypes: recommendedContentTypes
                ) { bundledVideo in
                    if let asset = VideoManager.loadBundledVideo(bundledVideo) {
                        selectedVideo = asset
                        loadVideoInfo(asset)
                    }
                    showingBundledVideoPicker = false
                }
            }
        }
        .onChange(of: selectedVideo) { _, newValue in
            if let video = newValue {
                loadVideoInfo(video)
            } else {
                videoMetadata = nil
                videoThumbnail = nil
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                await loadPhotoLibraryVideo(newItem)
            }
        }
    }

    // MARK: - Subviews

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Video Selected")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Choose from bundled samples or your photo library")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: 300)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("No video selected. Choose a video to analyze.")
    }

    // MARK: - Helper Methods

    private func loadVideoInfo(_ asset: AVAsset) {
        Task {
            do {
                // Load metadata
                let metadata = try await VideoManager.metadata(for: asset)
                await MainActor.run {
                    self.videoMetadata = metadata
                }

                // Load first frame as thumbnail
                let thumbnail = try await VideoManager.extractFirstFrame(from: asset)
                await MainActor.run {
                    self.videoThumbnail = UIImage(cgImage: thumbnail)
                }
            } catch {
                print("Failed to load video info: \(error)")
            }
        }
    }

    private func loadPhotoLibraryVideo(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            // Load the video URL from the photo library item
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                print("Failed to load video from photo library")
                return
            }

            // Create AVAsset from the URL
            let asset = AVURLAsset(url: movie.url)

            await MainActor.run {
                self.selectedVideo = asset
            }
        } catch {
            print("Error loading video from photo library: \(error)")
        }
    }
}

// MARK: - Supporting Views

/// Metadata display item
struct MetadataItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
    }
}

/// Video source button
struct VideoSourceButton: View {
    let icon: String
    let label: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VideoSourceButtonLabel(icon: icon, label: label)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Button label for video source buttons
struct VideoSourceButtonLabel: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
            Text(label)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Bundled Video Picker

/// Sheet view for selecting a bundled video
struct BundledVideoPickerView: View {
    let recommendedContentTypes: Set<ImageContentType>
    let onSelect: (BundledVideo) -> Void

    @Environment(\.dismiss) private var dismiss

    private var availableVideos: [BundledVideo] {
        let allVideos = VideoManager.availableVideos()

        if recommendedContentTypes.isEmpty {
            return allVideos
        }

        return allVideos.filter { video in
            !video.contentTypes.isDisjoint(with: recommendedContentTypes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(availableVideos) { video in
                        BundledVideoCard(video: video) {
                            onSelect(video)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Video")
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

/// Card displaying bundled video information
struct BundledVideoCard: View {
    let video: BundledVideo
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Video thumbnail
                if let thumbnail = thumbnail {
                    ZStack(alignment: .center) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 100, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        ProgressView()
                    }
                }

                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.name)
                        .font(.headline)

                    Text(video.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(video.name). \(video.description)")
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let asset = VideoManager.loadBundledVideo(video) else { return }

        do {
            let cgImage = try await VideoManager.extractFirstFrame(from: asset)
            await MainActor.run {
                self.thumbnail = UIImage(cgImage: cgImage)
            }
        } catch {
            print("Failed to load thumbnail for \(video.name): \(error)")
        }
    }
}

// MARK: - Video Transferable

/// Transferable type for loading videos from PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy the video to a temporary location
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            try FileManager.default.copyItem(at: received.file, to: tempURL)

            return Self(url: tempURL)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedVideo: AVAsset?

        var body: some View {
            VideoSelectionView(
                selectedVideo: $selectedVideo,
                recommendedContentTypes: [.animals, .objects]
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
