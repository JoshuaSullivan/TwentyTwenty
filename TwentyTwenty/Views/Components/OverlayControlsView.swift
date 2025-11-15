import SwiftUI

/// Controls for managing overlay display options
struct OverlayControlsView: View {
    /// Whether to show the overlay
    @Binding var showOverlay: Bool

    /// Opacity for bitmap overlays (0.0 to 1.0)
    @Binding var overlayOpacity: Double

    /// Whether the model supports opacity adjustment (bitmap overlays)
    let supportsOpacity: Bool

    /// Custom label for the overlay toggle
    let toggleLabel: String

    init(
        showOverlay: Binding<Bool>,
        overlayOpacity: Binding<Double> = .constant(0.5),
        supportsOpacity: Bool = false,
        toggleLabel: String = "Show Overlay"
    ) {
        self._showOverlay = showOverlay
        self._overlayOpacity = overlayOpacity
        self.supportsOpacity = supportsOpacity
        self.toggleLabel = toggleLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle switch
            Toggle(isOn: $showOverlay) {
                Label(toggleLabel, systemImage: "eye")
                    .font(.subheadline)
            }
            .accessibilityLabel(toggleLabel)
            .accessibilityValue(showOverlay ? "On" : "Off")

            // Opacity slider (only for bitmap overlays)
            if supportsOpacity && showOverlay {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacity")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(String(format: "%.0f%%", overlayOpacity * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $overlayOpacity, in: 0.1...1.0, step: 0.1)
                        .accessibilityLabel("Overlay opacity")
                        .accessibilityValue(String(format: "%.0f percent", overlayOpacity * 100))
                }
                .padding(.leading, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: showOverlay)
    }
}

// MARK: - Compact Variant

/// Compact overlay controls for use in constrained spaces
struct CompactOverlayControlsView: View {
    @Binding var showOverlay: Bool
    @Binding var overlayOpacity: Double
    let supportsOpacity: Bool

    init(
        showOverlay: Binding<Bool>,
        overlayOpacity: Binding<Double> = .constant(0.5),
        supportsOpacity: Bool = false
    ) {
        self._showOverlay = showOverlay
        self._overlayOpacity = overlayOpacity
        self.supportsOpacity = supportsOpacity
    }

    var body: some View {
        HStack(spacing: 16) {
            // Toggle button
            Button {
                withAnimation {
                    showOverlay.toggle()
                }
            } label: {
                Label(
                    showOverlay ? "Hide Overlay" : "Show Overlay",
                    systemImage: showOverlay ? "eye.slash" : "eye"
                )
                .labelStyle(.iconOnly)
                .font(.title3)
            }
            .accessibilityLabel(showOverlay ? "Hide overlay" : "Show overlay")

            // Opacity slider (only shown when overlay is visible and supported)
            if supportsOpacity && showOverlay {
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: $overlayOpacity, in: 0.1...1.0, step: 0.1)
                        .frame(maxWidth: 120)

                    Text(String(format: "%.0f%%", overlayOpacity * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showOverlay)
    }
}

// MARK: - Preview

#Preview("Full Controls") {
    VStack(spacing: 20) {
        OverlayControlsView(
            showOverlay: .constant(true),
            overlayOpacity: .constant(0.5),
            supportsOpacity: true,
            toggleLabel: "Show Detection Overlay"
        )

        OverlayControlsView(
            showOverlay: .constant(false),
            overlayOpacity: .constant(0.5),
            supportsOpacity: false,
            toggleLabel: "Show Bounding Boxes"
        )
    }
    .padding()
}

#Preview("Compact Controls") {
    VStack(spacing: 20) {
        CompactOverlayControlsView(
            showOverlay: .constant(true),
            overlayOpacity: .constant(0.7),
            supportsOpacity: true
        )

        CompactOverlayControlsView(
            showOverlay: .constant(false),
            overlayOpacity: .constant(0.5),
            supportsOpacity: false
        )
    }
    .padding()
}
