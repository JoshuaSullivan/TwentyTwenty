import SwiftUI

/// Detail view for the Generate Foreground Instance Mask model
struct GenerateForegroundInstanceMaskView: View {
    let model: VisionModel

    @State private var viewModel: GenerateForegroundInstanceMaskViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GenerateForegroundInstanceMaskViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.foregroundInstances.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Foreground Instance Masks")
                        .font(.headline)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.layers.3d.down.right")
                                .foregroundStyle(.blue)
                            let totalInstances = viewModel.foregroundInstances.reduce(0) { $0 + $1.instanceCount }
                            Text("\(totalInstances) object(s)")
                                .font(.subheadline)
                        }

                        Divider()
                            .frame(height: 20)

                        HStack(spacing: 6) {
                            Image(systemName: "square.split.diagonal.2x2")
                                .foregroundStyle(.green)
                            Text("Foreground/Background")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    ForEach(viewModel.foregroundInstances) { instance in
                        ForegroundInstanceCard(instance: instance)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Foreground Instance Masks")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model separates foreground objects from the background and generates individual masks for each distinct object. Unlike person-specific masks, this works on any foreground subject including people, animals, objects, and more. Great for subject isolation and background replacement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        })
    }
}

// MARK: - Foreground Instance Card

/// Card displaying foreground instance information
struct ForegroundInstanceCard: View {
    let instance: ForegroundInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.on.square")
                        .foregroundStyle(.blue)
                    Text("Mask \(instance.index + 1)")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", instance.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(instance.confidence))
            }

            // Instance details
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Foreground Objects")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "cube.fill")
                                .foregroundStyle(.blue)
                            Text("\(instance.instanceCount)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Divider()

                Text("Each foreground object has been separated from the background with its own instance mask, enabling precise subject isolation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Foreground instance mask, \(instance.instanceCount) objects detected")
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

// MARK: - Preview

#Preview {
    NavigationStack {
        GenerateForegroundInstanceMaskView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .generateForegroundInstanceMask })!
        )
    }
}
