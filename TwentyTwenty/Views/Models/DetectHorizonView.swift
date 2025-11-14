import SwiftUI

/// Detail view for the Detect Horizon model
struct DetectHorizonView: View {
    let model: VisionModel

    @State private var viewModel: DetectHorizonViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectHorizonViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(viewModel: viewModel, resultsView: {
            // Results View
            if let horizon = viewModel.detectedHorizon {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Horizon Analysis")
                        .font(.headline)

                    // Main angle display
                    VStack(spacing: 16) {
                        // Angle indicator
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 8)
                                .frame(width: 140, height: 140)

                            // Horizon line
                            Rectangle()
                                .fill(horizon.isLevel ? Color.green : Color.orange)
                                .frame(width: 100, height: 3)
                                .rotationEffect(.degrees(horizon.angleDegrees))

                            // Center dot
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 8, height: 8)
                        }

                        VStack(spacing: 8) {
                            Text(String(format: "%.2f°", horizon.angleDegrees))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(horizon.isLevel ? .green : .primary)

                            Text(horizon.tiltDirection)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Angle details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Angle (Radians)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(String(format: "%.4f", horizon.angle))
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Status")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    Image(systemName: horizon.isLevel ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    Text(horizon.isLevel ? "Level" : "Tilted")
                                }
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(horizon.isLevel ? .green : .orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Horizon Detection")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("The horizon angle indicates how level the camera was when the photo was taken. An angle close to 0° means the horizon is level. Positive angles indicate a tilt to the right, negative angles indicate a tilt to the left.")
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

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectHorizonView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectHorizon })!
        )
    }
}
