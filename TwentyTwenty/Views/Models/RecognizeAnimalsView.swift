import SwiftUI

/// Detail view for the Recognize Animals model
struct RecognizeAnimalsView: View {
    let model: VisionModel

    @State private var viewModel: RecognizeAnimalsViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: RecognizeAnimalsViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if !viewModel.recognizedAnimals.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recognized Animals")
                        .font(.headline)

                    Text("\(viewModel.recognizedAnimals.count) animal(s) recognized")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.recognizedAnimals) { animal in
                        RecognizedAnimalCard(animal: animal)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Animal Recognition")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("This model identifies and classifies animals in images, primarily focusing on cats and dogs. It provides both the species classification and a bounding box location.")
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

// MARK: - Recognized Animal Card

/// Card displaying recognized animal information
struct RecognizedAnimalCard: View {
    let animal: RecognizedAnimal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.blue)
                    Text("Animal \(animal.index + 1)")
                        .font(.headline)
                }

                Spacer()

                Label(
                    String(format: "%.1f%%", animal.confidence * 100),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(confidenceColor(animal.confidence))
            }

            // Top classification
            VStack(alignment: .leading, spacing: 8) {
                Text("Classification")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(animal.topLabel)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // All labels if multiple
            if animal.labels.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All Classifications")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(animal.labels) { label in
                        HStack {
                            Text(label.displayName)
                                .font(.caption)

                            Spacer()

                            HStack(spacing: 4) {
                                Text(String(format: "%.1f%%", label.confidence * 100))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                ProgressView(value: Double(label.confidence))
                                    .frame(width: 60)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Bounding box info
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Position")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(animal.boundingBox.origin.x)), \(Int(animal.boundingBox.origin.y)))")
                            .font(.caption)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Size")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(animal.boundingBox.width)) × \(Int(animal.boundingBox.height))")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Animal \(animal.index + 1), \(animal.topLabel), confidence \(String(format: "%.0f%%", animal.confidence * 100))")
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
        RecognizeAnimalsView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .recognizeAnimals })!
        )
    }
}
