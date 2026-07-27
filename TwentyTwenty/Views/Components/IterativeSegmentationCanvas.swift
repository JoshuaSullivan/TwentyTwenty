import SwiftUI

/// Interactive workbench for seeding and refining an iterative segmentation.
///
/// The view is deliberately free of any ViewModel dependency: state comes in as values and
/// interactions go out as closures. That keeps it previewable and lets it live below the
/// iOS 27 availability boundary that the segmentation ViewModel sits behind.
///
/// All point and rect values crossing this boundary are normalized with a **top-left
/// origin**. Conversion to Vision's bottom-left space is the caller's responsibility.
struct IterativeSegmentationCanvas: View {
    /// The image being segmented, already normalized to `.up` orientation.
    let image: UIImage

    /// Tinted mask from the most recent run, drawn over the image.
    let overlay: UIImage?

    /// How the next seeding interaction is interpreted.
    let seedMode: SeedMode

    /// The active seed, drawn as a marker.
    let seed: SegmentationSeed?

    /// Refinement points placed on top of the seed.
    let refinementPoints: [RefinementPoint]

    /// Whether a run is currently in flight.
    let isProcessing: Bool

    /// Whether the canvas should accept a seeding interaction.
    let canSeed: Bool

    /// Whether the canvas should accept a refinement tap.
    let canAddRefinementPoint: Bool

    /// Called when the user produces a new seed.
    let onSeed: (SegmentationSeed) -> Void

    /// Called when the user places a refinement point.
    let onRefine: (CGPoint) -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var strokes: [[CGPoint]] = []
    @State private var activeStroke: [CGPoint] = []

    private let markerSize: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            let fit = AspectFitGeometry(imageSize: image.size, viewSize: geometry.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                if let overlay {
                    Image(uiImage: overlay)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.55)
                        .allowsHitTesting(false)
                }

                seedMarker(in: fit)
                inProgressShape(in: fit)

                ForEach(refinementPoints) { point in
                    marker(
                        systemImage: point.polarity.systemImage,
                        fill: point.polarity == .include ? .green : .red
                    )
                    .position(fit.viewPoint(fromNormalizedTopLeft: point.location))
                }

                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                        .background(.regularMaterial, in: .circle)
                }

                interactionLayer(in: fit)
            }
        }
        .aspectRatio(image.size, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.tint, lineWidth: 2)
        }
        .onChange(of: seed) { _, newSeed in
            // The owner cleared or replaced the seed (reset, mode switch, new image) —
            // drop the locally accumulated strokes so they can't be replayed.
            if newSeed == nil {
                strokes = []
                activeStroke = []
            }
        }
        .accessibilityLabel("Segmentation canvas")
        .accessibilityHint(seedMode.instruction)
    }

    // MARK: - Interaction

    @ViewBuilder
    private func interactionLayer(in fit: AspectFitGeometry) -> some View {
        switch seedMode {
        case .point:
            Color.clear
                .contentShape(.rect)
                .onTapGesture { location in
                    handleTap(at: location, in: fit)
                }

        case .box:
            // Drag draws the seed box; once seeded, a plain tap refines.
            Color.clear
                .contentShape(.rect)
                .gesture(boxGesture(in: fit))
                .onTapGesture { location in
                    guard seed != nil else { return }
                    handleTap(at: location, in: fit)
                }

        case .scribble:
            // A single gesture handles both: a real drag adds a stroke, while a
            // tap-sized gesture refines once a seed exists.
            Color.clear
                .contentShape(.rect)
                .gesture(scribbleGesture(in: fit))
        }
    }

    private func handleTap(at location: CGPoint, in fit: AspectFitGeometry) {
        let normalized = fit.normalizedTopLeft(from: location)

        if seed == nil {
            guard canSeed, seedMode == .point else { return }
            onSeed(.point(normalized))
        } else {
            guard canAddRefinementPoint else { return }
            onRefine(normalized)
        }
    }

    private func boxGesture(in fit: AspectFitGeometry) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard canSeed else { return }
                if dragStart == nil { dragStart = value.startLocation }
                dragCurrent = value.location
            }
            .onEnded { value in
                defer {
                    dragStart = nil
                    dragCurrent = nil
                }
                guard canSeed, let start = dragStart else { return }

                let a = fit.normalizedTopLeft(from: start)
                let b = fit.normalizedTopLeft(from: value.location)
                let rect = CGRect(
                    x: min(a.x, b.x),
                    y: min(a.y, b.y),
                    width: abs(a.x - b.x),
                    height: abs(a.y - b.y)
                )

                // Ignore accidental hairline drags.
                guard rect.width > 0.02, rect.height > 0.02 else { return }
                onSeed(.box(rect))
            }
    }

    private func scribbleGesture(in fit: AspectFitGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canSeed else { return }
                activeStroke.append(fit.normalizedTopLeft(from: value.location))
            }
            .onEnded { value in
                defer { activeStroke = [] }
                guard canSeed, !activeStroke.isEmpty else { return }

                let travel = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )

                // A tap-sized gesture on an existing seed refines rather than redraws.
                if seed != nil, travel < 10 {
                    guard canAddRefinementPoint else { return }
                    onRefine(fit.normalizedTopLeft(from: value.location))
                    return
                }

                strokes.append(activeStroke)
                onSeed(.scribble(strokes))
            }
    }

    // MARK: - Markers

    @ViewBuilder
    private func seedMarker(in fit: AspectFitGeometry) -> some View {
        switch seed {
        case .point(let point):
            marker(systemImage: "scope", fill: .yellow)
                .position(fit.viewPoint(fromNormalizedTopLeft: point))

        case .box(let rect):
            let viewRect = fit.viewRect(fromNormalizedTopLeft: rect)
            Rectangle()
                .stroke(.yellow, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: viewRect.width, height: viewRect.height)
                .position(x: viewRect.midX, y: viewRect.midY)
                .allowsHitTesting(false)

        case .scribble(let paths):
            strokePath(paths, in: fit)
                .stroke(.yellow, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)

        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func inProgressShape(in fit: AspectFitGeometry) -> some View {
        if seedMode == .box, let start = dragStart, let current = dragCurrent {
            let rect = CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(start.x - current.x),
                height: abs(start.y - current.y)
            )
            Rectangle()
                .stroke(.yellow, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }

        if seedMode == .scribble, !activeStroke.isEmpty {
            strokePath([activeStroke], in: fit)
                .stroke(.yellow, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
        }
    }

    private func strokePath(_ paths: [[CGPoint]], in fit: AspectFitGeometry) -> Path {
        Path { path in
            for stroke in paths where !stroke.isEmpty {
                let points = stroke.map { fit.viewPoint(fromNormalizedTopLeft: $0) }
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
    }

    /// A circular marker with a white halo so it stays legible over any image.
    private func marker(systemImage: String, fill: Color) -> some View {
        Image(systemName: systemImage)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: markerSize, height: markerSize)
            .background(fill, in: .circle)
            .overlay {
                Circle().stroke(.white, lineWidth: 2)
            }
            .shadow(radius: 2)
            .allowsHitTesting(false)
    }
}
