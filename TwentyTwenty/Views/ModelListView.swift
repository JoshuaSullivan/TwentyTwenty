import SwiftUI

/// Main view displaying the list of Vision models with filtering
struct ModelListView: View {
    @State private var viewModel = ModelListViewModel()

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Filter Section

                Section {
                    filterPicker
                } header: {
                    Text("Filter")
                }

                // MARK: - Models Section

                ForEach(viewModel.modelsByCategory, id: \.category) { categoryGroup in
                    Section {
                        ForEach(categoryGroup.models) { model in
                            NavigationLink(value: model) {
                                ModelRow(model: model)
                            }
                            .accessibilityLabel("\(model.name), requires iOS \(formattedVersion(model.minimumIOSVersion))")
                        }
                    } header: {
                        Text(categoryGroup.category.rawValue)
                    }
                }
            }
            .navigationTitle("Vision Models")
            .navigationDestination(for: VisionModel.self) { model in
                ModelDetailPlaceholder(model: model)
            }
        }
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Minimum iOS Version", selection: $viewModel.selectedIOSVersion) {
            Text("All Versions")
                .tag(nil as Double?)
                .accessibilityLabel("Show all iOS versions")

            ForEach(viewModel.availableIOSVersions, id: \.self) { version in
                Text("iOS \(formattedVersion(version))+")
                    .tag(version as Double?)
                    .accessibilityLabel("Show models available in iOS \(formattedVersion(version)) and later")
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Filter by minimum iOS version")
    }

    // MARK: - Helpers

    private func formattedVersion(_ version: Double) -> String {
        String(format: "%.1f", version)
    }
}

// MARK: - Model Row

/// Individual row displaying a Vision model
struct ModelRow: View {
    let model: VisionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.name)
                .font(.headline)

            Text(model.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Label("iOS \(formattedVersion(model.minimumIOSVersion))+", systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(model.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(for: model.category).opacity(0.2))
                    .foregroundStyle(categoryColor(for: model.category))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

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

// MARK: - Placeholder Detail View

/// Placeholder view for model details (to be implemented in Phase 4)
struct ModelDetailPlaceholder: View {
    let model: VisionModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "eye.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(model.name)
                .font(.title)

            Text(model.description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Text("Detail view coming in Phase 4")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ModelListView()
}
