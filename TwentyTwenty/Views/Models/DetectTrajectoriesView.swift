import SwiftUI

/// Detail view for the Detect Trajectories model
struct DetectTrajectoriesView: View {
    let model: VisionModel

    @State private var viewModel: DetectTrajectoriesViewModel

    init(model: VisionModel) {
        self.model = model
        self._viewModel = State(initialValue: DetectTrajectoriesViewModel(model: model))
    }

    var body: some View {
        ModelDetailView(
            viewModel: viewModel,
            resultsView: {
                if !viewModel.detectedTrajectories.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trajectory Detection Results")
                            .font(.headline)

                        Text("Detected \(viewModel.detectedTrajectories.count) trajectory/trajectories")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(Array(viewModel.detectedTrajectories.enumerated()), id: \.offset) { index, trajectory in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "point.3.connected.trianglepath.dotted")
                                        .foregroundStyle(.blue)
                                    Text("Trajectory \(index + 1)")
                                        .font(.headline)

                                    Spacer()

                                    Text(String(format: "%.0f%%", trajectory.confidence * 100))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(trajectory.confidence > 0.8 ? .green : trajectory.confidence > 0.5 ? .orange : .red)
                                }

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Detected Points")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(trajectory.detectedPoints.count)")
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }

                                    Divider()
                                        .frame(height: 30)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Projected Points")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(trajectory.projectedPoints.count)")
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text("Note: Full trajectory visualization coming soon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetectTrajectoriesView(
            model: VisionModelRegistry.allModels.first(where: { $0.requestType == .detectTrajectories })!
        )
    }
}
