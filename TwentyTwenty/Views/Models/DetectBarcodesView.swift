import SwiftUI
import Vision

/// Detail view for the Detect Barcodes model
struct DetectBarcodesView: View {
    let model: VisionModel

    @State private var viewModel: DetectBarcodesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectBarcodesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, configurationView: {
            // Configuration View
            VStack(alignment: .leading, spacing: 12) {
                Text("Symbologies")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SymbologyPicker(selectedSymbologies: $viewModel.selectedSymbologies)
            }
        }, resultsView: {
            // Results View
            if !viewModel.detectedBarcodes.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Barcodes")
                        .font(.headline)

                    ForEach(viewModel.detectedBarcodes) { barcode in
                        BarcodeCard(barcode: barcode)
                    }
                }
            }
        })
    }
}

// MARK: - Symbology Picker

/// Picker for selecting which barcode symbologies to detect
struct SymbologyPicker: View {
    @Binding var selectedSymbologies: Set<BarcodeSymbology>

    private let commonSymbologies: [(BarcodeSymbology, String)] = [
        (.qr, "QR Code"),
        (.ean13, "EAN-13"),
        (.ean8, "EAN-8"),
        (.upce, "UPC-E"),
        (.code128, "Code 128"),
        (.code39, "Code 39"),
        (.code93, "Code 93"),
        (.pdf417, "PDF417")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(commonSymbologies, id: \.0) { symbology, name in
                Toggle(name, isOn: Binding(
                    get: { selectedSymbologies.contains(symbology) },
                    set: { isSelected in
                        if isSelected {
                            selectedSymbologies.insert(symbology)
                        } else {
                            selectedSymbologies.remove(symbology)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .accessibilityLabel("Detect \(name) barcodes")
            }
        }
    }
}

// MARK: - Barcode Card

/// Card displaying information about a detected barcode
struct BarcodeCard: View {
    let barcode: DetectedBarcode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(barcode.symbologyName)
                        .font(.headline)

                    if let payload = barcode.payloadString {
                        Text(payload)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text("No payload data")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label(
                        String(format: "%.1f%%", barcode.confidence * 100),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(confidenceColor(barcode.confidence))
                }
            }

            HStack(spacing: 16) {
                InfoLabel(icon: "arrow.left.and.right", text: String(format: "%.0f px", barcode.boundingBox.width))
                InfoLabel(icon: "arrow.up.and.down", text: String(format: "%.0f px", barcode.boundingBox.height))
                InfoLabel(icon: "location", text: String(format: "(%.0f, %.0f)", barcode.boundingBox.origin.x, barcode.boundingBox.origin.y))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Detected \(barcode.symbologyName), \(barcode.payloadString ?? "no data"), confidence \(String(format: "%.0f%%", barcode.confidence * 100))")
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

// MARK: - Info Label

/// Small info label with icon and text
struct InfoLabel: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectBarcodesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectBarcodes })!
        )
    }
}
