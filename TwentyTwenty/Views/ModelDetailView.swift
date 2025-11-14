import SwiftUI

/// Generic template view for displaying Vision model details and results
/// This view provides the standard layout used across all model detail pages
struct ModelDetailView<ViewModel: BaseModelDetailViewModel, ConfigurationView: View, ResultsView: View>: View {
    /// The ViewModel managing this detail view
    @State var viewModel: ViewModel

    /// View builder for model-specific configuration controls
    let configurationView: () -> ConfigurationView

    /// View builder for model-specific results display
    let resultsView: () -> ResultsView

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Model Description

                descriptionSection

                // MARK: - Image Selection

                ImageSelectionView(
                    selectedImage: $viewModel.selectedImage,
                    recommendedContentTypes: viewModel.recommendedContentTypes
                )
                .padding(.horizontal)

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
                await viewModel.processImage()
            }
        } label: {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }

                Text(viewModel.isProcessing ? "Processing..." : "Analyze Image")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.selectedImage == nil || viewModel.isProcessing ? Color.gray : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.selectedImage == nil || viewModel.isProcessing)
        .padding(.horizontal)
        .accessibilityLabel(viewModel.isProcessing ? "Processing image" : "Analyze image with Vision model")
        .accessibilityHint(viewModel.selectedImage == nil ? "Select an image first" : "")
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
