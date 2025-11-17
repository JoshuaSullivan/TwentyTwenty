import SwiftUI

/// Detail view for the Generate Image Feature Print model
struct GenerateImageFeaturePrintView: View {
    let model: VisionModel

    @State private var viewModel: GenerateImageFeaturePrintViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GenerateImageFeaturePrintViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.featurePrintResults.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Image Feature Print")
                        .font(.headline)

                    ForEach(viewModel.featurePrintResults) { result in
                        FeaturePrintCard(result: result)
                    }

                    // Info about feature prints
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Feature Prints")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("Feature prints are numerical representations of an image's visual characteristics. They can be used to compare images, find similar images, or measure visual similarity. The feature vector encodes properties like shapes, textures, and patterns.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Use cases
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Use Cases")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 6) {
                            UseCaseRow(icon: "magnifyingglass", text: "Find visually similar images")
                            UseCaseRow(icon: "photo.stack", text: "Organize photo libraries")
                            UseCaseRow(icon: "shuffle", text: "Detect duplicate or near-duplicate images")
                            UseCaseRow(icon: "chart.bar", text: "Measure visual similarity between images")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        })
    }
}

// MARK: - Feature Print Card

/// Card displaying feature print information
struct FeaturePrintCard: View {
    let result: ImageFeaturePrint

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Feature Vector")
                    .font(.headline)

                Spacer()

                Label(
                    String(format: "%.1f%%", result.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(result.confidence))
            }

            // Feature vector details
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("\(result.elementCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("Dimensions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 8) {
                        Text(result.elementType)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("Element Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Visual representation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vector Representation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 32)

                    LazyVGrid(columns: gridColumns, spacing: 1) {
                        ForEach(0..<768, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.accentColor.opacity(Double.random(in: 0.3...1.0)))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text("32×24 grid (768 dimensions)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Feature print with \(result.elementCount) dimensions, confidence \(String(format: "%.0f%%", result.confidence * 100))")
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.9 {
            return .green
        } else if confidence > 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Use Case Row

/// Row displaying a use case
struct UseCaseRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenerateImageFeaturePrintView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .generateImageFeaturePrint })!
        )
    }
}
