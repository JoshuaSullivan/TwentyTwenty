// Requires the iOS 27 SDK for `GenerateIterativeSegmentationRequest`; Swift 6.4 ships with
// Xcode 27. See `GenerateIterativeSegmentationViewModel` for the full explanation.
#if compiler(>=6.4)

import SwiftUI
import Vision

/// Detail view for the Generate Iterative Segmentation model.
@available(iOS 27.0, *)
struct GenerateIterativeSegmentationView: View {
    let model: VisionModel

    @State private var viewModel: GenerateIterativeSegmentationViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GenerateIterativeSegmentationViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            VStack(alignment: .leading, spacing: 16) {
                SegmentationAssetPanel(
                    state: viewModel.assetState,
                    fraction: viewModel.downloadFraction,
                    isIndeterminate: viewModel.downloadIsIndeterminate,
                    onDownload: { Task { await viewModel.downloadAssets() } }
                )

                seedModeSection
                canvasSection
                qualitySection
            }
        }, resultsView: {
            if viewModel.maskObservation != nil {
                resultsSection
            }
        })
        .task {
            await viewModel.refreshAssetStatus()
        }
    }

    // MARK: - Configuration Sections

    private var seedModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seed Mode")
                .font(.subheadline)
                .bold()

            Picker("Seed Mode", selection: $viewModel.seedMode) {
                ForEach(SeedMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(viewModel.seedMode.instruction)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var canvasSection: some View {
        if let image = viewModel.sourceImage {
            VStack(alignment: .leading, spacing: 12) {
                IterativeSegmentationCanvas(
                    image: image,
                    overlay: viewModel.overlayImage,
                    seedMode: viewModel.seedMode,
                    seed: viewModel.seed,
                    refinementPoints: viewModel.refinementPoints,
                    isProcessing: viewModel.isProcessing,
                    canSeed: viewModel.canSeed,
                    canAddRefinementPoint: viewModel.canAddRefinementPoint,
                    onSeed: { viewModel.setSeed($0) },
                    onRefine: { viewModel.addRefinementPoint(at: $0) }
                )
                .opacity(viewModel.assetState == .ready ? 1 : 0.4)

                if viewModel.seed == nil {
                    Button("Seed at Center", systemImage: "scope") {
                        viewModel.seedAtCenter()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canSeed)
                } else {
                    refinementControls
                }
            }
        }
    }

    private var refinementControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Refinement Points")
                    .font(.subheadline)
                    .bold()

                Picker("Point Type", selection: $viewModel.pointPolarity) {
                    ForEach(RefinementPolarity.allCases) { polarity in
                        Text(polarity.title).tag(polarity)
                    }
                }
                .pickerStyle(.segmented)

                Text("Tap the object to add points. \(viewModel.remainingRefinementPoints) of \(viewModel.maxRefinementPoints) remaining.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    viewModel.undoLastPoint()
                }
                .disabled(viewModel.refinementPoints.isEmpty || viewModel.isProcessing)

                Button("Clear Points", systemImage: "xmark.circle") {
                    viewModel.clearRefinementPoints()
                }
                .disabled(viewModel.refinementPoints.isEmpty || viewModel.isProcessing)

                Button("Reset Seed", systemImage: "arrow.counterclockwise") {
                    viewModel.resetSeed()
                }
                .disabled(viewModel.isProcessing)
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quality Level")
                .font(.subheadline)
                .bold()

            Picker("Quality Level", selection: $viewModel.qualityLevel) {
                Text("Accurate").tag(GenerateIterativeSegmentationRequest.QualityLevel.accurate)
                Text("Balanced").tag(GenerateIterativeSegmentationRequest.QualityLevel.balanced)
                Text("Fast").tag(GenerateIterativeSegmentationRequest.QualityLevel.fast)
            }
            .pickerStyle(.segmented)

            Text("Higher quality takes longer, and the request re-runs on every point you add.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Iterative Segmentation Results")
                .font(.headline)

            IterativeSegmentationCard(
                confidence: viewModel.confidence,
                iterationCount: viewModel.iterationCount,
                includeCount: viewModel.refinementPoints.filter { $0.polarity == .include }.count,
                excludeCount: viewModel.refinementPoints.filter { $0.polarity == .exclude }.count,
                seedMode: viewModel.seedMode,
                qualityLevel: viewModel.qualityLevel
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("About Iterative Segmentation")
                    .font(.caption)
                    .bold()

                Text("Introduced in iOS 27, this request segments any object — not just people or a generic foreground. You seed it with a point, a box, or a scribble, then steer the result by adding points that mark regions to include or exclude. Each point re-runs the request, reusing the image analysis it already cached, so later iterations are usually faster than the first. The model isn't bundled with iOS and is downloaded on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
}

// MARK: - Asset Panel

/// Shows the download state of the segmentation model and offers to fetch it.
@available(iOS 27.0, *)
struct SegmentationAssetPanel: View {
    let state: SegmentationAssetState
    let fraction: Double
    let isIndeterminate: Bool
    let onDownload: () -> Void

    var body: some View {
        switch state {
        case .ready:
            EmptyView()

        case .unknown:
            Label("Checking for the segmentation model…", systemImage: "arrow.trianglehead.2.clockwise")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .notReady:
            panel {
                Text("This model isn't on your device yet. Download it to start segmenting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Download Model", systemImage: "arrow.down.circle", action: onDownload)
                    .buttonStyle(.borderedProminent)
            }

        case .downloading:
            panel {
                Text("Downloading the segmentation model…")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isIndeterminate {
                    ProgressView()
                        .progressViewStyle(.linear)
                } else {
                    ProgressView(value: fraction)
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

        case .failed(let message):
            panel {
                Label("Couldn't prepare the model", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)

                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Try Again", systemImage: "arrow.clockwise", action: onDownload)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Results Card

/// Card summarizing the most recent iterative segmentation run.
@available(iOS 27.0, *)
struct IterativeSegmentationCard: View {
    let confidence: Float?
    let iterationCount: Int
    let includeCount: Int
    let excludeCount: Int
    let seedMode: SeedMode
    let qualityLevel: GenerateIterativeSegmentationRequest.QualityLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Segmentation Mask", systemImage: "square.on.square.dashed")
                    .font(.headline)

                Spacer()

                if let confidence {
                    Label(
                        Double(confidence).formatted(.percent.precision(.fractionLength(1))),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(confidenceColor(confidence))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    statistic("Iterations", value: iterationCount.formatted(.number))
                    statistic("Included", value: includeCount.formatted(.number))
                    statistic("Excluded", value: excludeCount.formatted(.number))
                }

                Divider()

                HStack(spacing: 24) {
                    statistic("Seed", value: seedMode.title)
                    statistic("Quality", value: qualityTitle)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(.rect(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Segmentation mask after \(iterationCount) iterations, \(includeCount) included and \(excludeCount) excluded points")
    }

    private var qualityTitle: String {
        switch qualityLevel {
        case .accurate: "Accurate"
        case .balanced: "Balanced"
        case .fast: "Fast"
        @unknown default: "Unknown"
        }
    }

    private func statistic(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.9 {
            .green
        } else if confidence > 0.7 {
            .orange
        } else {
            .red
        }
    }
}

// MARK: - Preview

@available(iOS 27.0, *)
#Preview {
    NavigationStack {
        GenerateIterativeSegmentationView(
            model: VisionModelRegistry.allModels.first { $0.requestType == .generateIterativeSegmentation }!
        )
    }
}

#endif
