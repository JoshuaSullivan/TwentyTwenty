import SwiftUI

/// Generic template view for displaying Vision model details and results
/// This view provides the standard layout used across all model detail pages
struct ModelDetailView<ViewModel: BaseModelDetailViewModel, ConfigurationView: View, ResultsView: View>: View {
    /// The ViewModel managing this detail view
    @State var viewModel: ViewModel

    /// View builder for model-specific configuration controls
    @ViewBuilder let configurationView: () -> ConfigurationView

    /// View builder for model-specific results display
    @ViewBuilder let resultsView: () -> ResultsView

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Model Description

                descriptionSection

                // MARK: - Image/Video Selection

                if viewModel.requiresVideo {
                    VideoSelectionView(
                        selectedVideo: $viewModel.selectedVideo,
                        recommendedContentTypes: viewModel.recommendedContentTypes
                    )
                    .padding(.horizontal)
                } else {
                    ImageSelectionView(
                        selectedImage: $viewModel.selectedImage,
                        recommendedContentTypes: viewModel.recommendedContentTypes,
                        overlayImage: viewModel.overlayImage,
                        overlayColor: $viewModel.overlayColor,
                        supportsColorTinting: viewModel.supportsColorTinting
                    )
                    .padding(.horizontal)
                }

                // MARK: - Configuration Controls

                if ConfigurationView.self != EmptyView.self {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration")
                            .font(.headline)
                            .padding(.horizontal)

                        configurationView()
                            .padding(.horizontal)
                    }
                }

                // MARK: - Process Button

                processButton

                // MARK: - Error Display

                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                }

                // MARK: - Results Display

                if ResultsView.self != EmptyView.self {
                    resultsView()
                        .padding(.horizontal)
                }

                // MARK: - Statistics

                if let statistics = viewModel.statistics {
                    StatisticsView(statistics: statistics)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.model.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("iOS \(formattedVersion(viewModel.model.minimumIOSVersion))+", systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.model.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(categoryColor(for: viewModel.model.category).opacity(0.2))
                    .foregroundStyle(categoryColor(for: viewModel.model.category))
                    .clipShape(Capsule())
            }

            Text(viewModel.model.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Process Button

    private var processButton: some View {
        Button {
            Task {
                if viewModel.requiresVideo {
                    await viewModel.processVideo()
                } else {
                    await viewModel.processImage()
                }
            }
        } label: {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: viewModel.requiresVideo ? "play.circle" : "wand.and.stars")
                }

                Text(viewModel.isProcessing ? "Processing..." : (viewModel.requiresVideo ? "Analyze Video" : "Analyze Image"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isProcessButtonDisabled ? Color.gray : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isProcessButtonDisabled)
        .padding(.horizontal)
        .accessibilityLabel(viewModel.isProcessing ? "Processing \(viewModel.requiresVideo ? "video" : "image")" : "Analyze \(viewModel.requiresVideo ? "video" : "image") with Vision model")
        .accessibilityHint(isProcessButtonDisabled ? "Select \(viewModel.requiresVideo ? "a video" : "an image") first" : "")
    }

    private var isProcessButtonDisabled: Bool {
        if viewModel.requiresVideo {
            return viewModel.selectedVideo == nil || viewModel.isProcessing
        } else {
            return viewModel.selectedImage == nil || viewModel.isProcessing
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Helpers

    private func formattedVersion(_ version: Double) -> String {
        String(format: "%.1f", version)
    }

    private func categoryColor(for category: VisionModelCategory) -> Color {
        switch category {
        case .detection:
            return .blue
        case .recognition:
            return .green
        case .generation:
            return .purple
        case .tracking:
            return .orange
        case .classification:
            return .pink
        case .utility:
            return .brown
        }
    }
}

// MARK: - Convenience Initializers

extension ModelDetailView where ConfigurationView == EmptyView {
    /// Initializer for models without configuration options
    init(
        viewModel: ViewModel,
        @ViewBuilder resultsView: @escaping () -> ResultsView
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.configurationView = { EmptyView() }
        self.resultsView = resultsView
    }
}

extension ModelDetailView where ResultsView == EmptyView {
    /// Initializer for models without results display
    init(
        viewModel: ViewModel,
        @ViewBuilder configurationView: @escaping () -> ConfigurationView
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.configurationView = configurationView
        self.resultsView = { EmptyView() }
    }
}

extension ModelDetailView where ConfigurationView == EmptyView, ResultsView == EmptyView {
    /// Initializer for models without configuration or results
    init(viewModel: ViewModel) {
        self._viewModel = State(initialValue: viewModel)
        self.configurationView = { EmptyView() }
        self.resultsView = { EmptyView() }
    }
}
