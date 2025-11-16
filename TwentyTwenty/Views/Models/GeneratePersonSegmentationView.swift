import SwiftUI
import Vision

/// Detail view for the Generate Person Segmentation model
struct GeneratePersonSegmentationView: View {
    let model: VisionModel

    @State private var viewModel: GeneratePersonSegmentationViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: GeneratePersonSegmentationViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            // Configuration View
            VStack(alignment: .leading, spacing: 12) {
                Text("Quality Level")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker("Quality Level", selection: $viewModel.qualityLevel) {
                    Text("Accurate").tag(GeneratePersonSegmentationRequest.QualityLevel.accurate)
                    Text("Balanced").tag(GeneratePersonSegmentationRequest.QualityLevel.balanced)
                }
                .pickerStyle(.segmented)

                Text("Accurate provides higher precision but takes longer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }, resultsView: {
            // Results View
            if let result = viewModel.segmentationResult {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Person Segmentation Results")
                        .font(.headline)

                    Text("Segmentation mask generated")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PersonSegmentationCard(result: result, qualityLevel: viewModel.qualityLevel)

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Person Segmentation")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model generates pixel-accurate segmentation masks that classify each pixel as either 'person' or 'not person'. Unlike instance masks which separate each person individually, this treats all people as a single class. Perfect for background removal and portrait mode effects.")
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

// MARK: - Person Segmentation Card

/// Card displaying person segmentation information
struct PersonSegmentationCard: View {
    let result: PersonSegmentation
    let qualityLevel: GeneratePersonSegmentationRequest.QualityLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle")
                        .foregroundStyle(.blue)
                    Text("Segmentation Mask")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", result.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(result.confidence))
            }

            // Segmentation details
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quality Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: qualityLevel == .accurate ? "slider.horizontal.2.square.on.square" : "slider.horizontal.2.square")
                                .foregroundStyle(.blue)
                            Text(qualityLevel == .accurate ? "Accurate" : "Balanced")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                }

                Divider()

                Text("A pixel-level segmentation mask has been generated to separate people from the background in this image.")
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
        .accessibilityLabel("Person segmentation mask generated")
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
        GeneratePersonSegmentationView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .generatePersonSegmentation })!
        )
    }
}
