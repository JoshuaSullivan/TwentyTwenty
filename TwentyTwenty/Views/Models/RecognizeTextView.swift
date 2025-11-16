import SwiftUI
import Vision

/// Detail view for the Recognize Text model (OCR)
struct RecognizeTextView: View {
    let model: VisionModel

    @State private var viewModel: RecognizeTextViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: RecognizeTextViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            // Configuration View
            VStack(alignment: .leading, spacing: 12) {
                Text("Recognition Level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Recognition Level", selection: $viewModel.recognitionLevel) {
                    Text("Fast").tag(RecognizeTextRequest.RecognitionLevel.fast)
                    Text("Accurate").tag(RecognizeTextRequest.RecognitionLevel.accurate)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Choose text recognition level: fast or accurate")
            }
        }, resultsView: {
            // Results View
            if !viewModel.recognizedTexts.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recognized Text")
                        .font(.headline)

                    // Full text display
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(viewModel.fullText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Individual text blocks
                    Text("Text Blocks (\(viewModel.recognizedTexts.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.recognizedTexts) { textBlock in
                        TextBlockCard(textBlock: textBlock)
                    }
                }
            }
        })
    }
}

// MARK: - Text Block Card

/// Card displaying a single recognized text block
struct TextBlockCard: View {
    let textBlock: RecognizedText

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(textBlock.text)
                    .font(.body)
                    .textSelection(.enabled)

                Spacer()

                Label(
                    String(format: "%.1f%%", textBlock.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(textBlock.confidence))
            }

            HStack(spacing: 16) {
                InfoLabel(icon: "arrow.left.and.right", text: String(format: "%.0f px", textBlock.boundingBox.width))
                InfoLabel(icon: "arrow.up.and.down", text: String(format: "%.0f px", textBlock.boundingBox.height))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recognized text: \(textBlock.text), confidence \(String(format: "%.0f%%", textBlock.confidence * 100))")
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
        RecognizeTextView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .recognizeText })!
        )
    }
}
