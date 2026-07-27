// `GenerateIterativeSegmentationRequest` is declared only in the iOS 27 SDK, and
// `@available` cannot help with that — it gates execution, not compilation. Swift 6.4 ships
// with Xcode 27, so this keeps the project building on Xcode 26, where the model appears in
// the list but routes to an availability notice instead.
#if compiler(>=6.4)

import CoreVideo
import Foundation
import Observation
import UIKit
import Vision

/// ViewModel for the Generate Iterative Segmentation model.
///
/// Unlike every other request in this app, `GenerateIterativeSegmentationRequest` is a
/// **class** that accumulates refinement state across successive `perform` calls, and its
/// model is downloaded on demand rather than shipped with the OS. Two consequences shape
/// this type:
///
/// - **The request is a cache; the stored arrays are the truth.** The request offers no way
///   to remove a point, so undo and reset are implemented by building a fresh request from
///   the seed and replaying the surviving points. The invariant is that the live request is
///   always exactly a function of `(seed, refinementPoints, qualityLevel)`.
/// - **Mutating the request emits no observation.** It is marked `@ObservationIgnored`, and
///   all UI binds to the mirrored state on this object instead.
@available(iOS 27.0, *)
@Observable
@MainActor
final class GenerateIterativeSegmentationViewModel: BaseModelDetailViewModel {
    // MARK: - BaseModelDetailViewModel Conformance

    let model: VisionModel

    var selectedImage: UIImage? {
        didSet {
            clearResults()
            prepareSource()
        }
    }

    var isProcessing = false
    var errorMessage: String?
    var statistics: PerformanceStatistics?

    var recommendedContentTypes: Set<ImageContentType> {
        [.objects, .animals, .people, .nature]
    }

    var overlayImage: UIImage? {
        renderedOverlay
    }

    var overlayColor: UIColor = UIColor(hue: 0.55, saturation: 1.0, brightness: 1.0, alpha: 1.0) {
        didSet {
            // Re-tint the existing mask; never re-run the request for a colour change.
            guard let observation = maskObservation, let size = sourceImage?.size else { return }
            Task { renderedOverlay = await Self.renderOverlay(observation: observation, imageSize: size, tint: overlayColor) }
        }
    }

    // MARK: - Seeding State

    /// How the next seed will be interpreted.
    var seedMode: SeedMode = .point {
        didSet {
            guard oldValue != seedMode else { return }
            resetSeed()
        }
    }

    /// The seed the current mask was built from, if any.
    private(set) var seed: SegmentationSeed?

    /// Refinement points applied on top of the seed, in the order they were added.
    private(set) var refinementPoints: [RefinementPoint] = []

    /// Whether the next canvas tap adds an include or an exclude point.
    var pointPolarity: RefinementPolarity = .include

    // MARK: - Request Configuration

    /// Accuracy/speed trade-off for the segmentation model.
    var qualityLevel: GenerateIterativeSegmentationRequest.QualityLevel = .balanced {
        didSet {
            guard oldValue != qualityLevel else { return }
            request?.qualityLevel = qualityLevel
            if seed != nil { runSegmentation() }
        }
    }

    // MARK: - Asset State

    /// Whether the downloadable segmentation model is available on device.
    private(set) var assetState: SegmentationAssetState = .unknown

    /// Download progress in the range `0...1`, valid while ``assetState`` is `.downloading`.
    private(set) var downloadFraction: Double = 0

    /// Whether the model reports indeterminate download progress.
    private(set) var downloadIsIndeterminate = false

    // MARK: - Results

    /// The mask produced by the most recent successful run.
    private(set) var maskObservation: PixelBufferObservation?

    /// Number of `perform` calls made against the current seed.
    private(set) var iterationCount = 0

    /// Confidence reported by the most recent mask.
    var confidence: Float? {
        maskObservation?.confidence
    }

    /// The orientation-normalized image the canvas displays and Vision analyzes.
    private(set) var sourceImage: UIImage?

    // MARK: - Non-Observable Machinery

    @ObservationIgnored private var request: GenerateIterativeSegmentationRequest?
    @ObservationIgnored private var sourceCGImage: CGImage?
    @ObservationIgnored private var activeTask: Task<Void, Never>?

    /// Pre-rendered mask overlay. Observed, so the image updates when a run completes.
    private var renderedOverlay: UIImage?

    // MARK: - Limits

    /// Maximum refinement points allowed on top of the current seed.
    ///
    /// Vision caps the total at 13 points for point and scribble seeding and 11 for box
    /// seeding; a point seed consumes one of those. The framework's own limit is
    /// authoritative — this value only drives the UI, and the throw from
    /// `addIncludedPoint`/`addExcludedPoint` is still handled.
    var maxRefinementPoints: Int {
        seedMode == .box ? 11 : 12
    }

    /// How many more refinement points the user may add.
    var remainingRefinementPoints: Int {
        max(0, maxRefinementPoints - refinementPoints.count)
    }

    /// Whether the canvas should accept a seeding interaction.
    var canSeed: Bool {
        sourceImage != nil && assetState == .ready && !isProcessing
    }

    /// Whether the canvas should accept a refinement tap.
    var canAddRefinementPoint: Bool {
        canSeed && seed != nil && remainingRefinementPoints > 0
    }

    // MARK: - Initialization

    init(model: VisionModel) {
        self.model = model
    }

    // MARK: - Processing

    /// Runs the request against the current seed.
    ///
    /// The shared `ModelDetailView` button routes here, but the real interaction loop runs
    /// automatically from ``setSeed(_:)`` and the refinement methods. This entry point
    /// therefore behaves as "re-run with whatever state exists", and explains itself when
    /// there is nothing to run yet.
    func processImage() async {
        guard selectedImage != nil else {
            errorMessage = "No image selected"
            return
        }

        guard await ensureAssetsReady() else { return }

        guard seed != nil else {
            errorMessage = "Tap the image in the configuration section to place a seed before analyzing."
            return
        }

        await performNow()
    }

    /// Tears down everything derived from the current image.
    ///
    /// Called from `selectedImage.didSet`, so it must drop the seed and the accumulated
    /// request state — otherwise the next run would refine the previous image's seed
    /// against the new picture. Asset state, quality level, seed mode and overlay colour
    /// deliberately survive: they describe the model and the user's preferences, not the image.
    func clearResults() {
        activeTask?.cancel()
        activeTask = nil
        request = nil
        sourceImage = nil
        sourceCGImage = nil
        seed = nil
        refinementPoints = []
        pointPolarity = .include
        maskObservation = nil
        renderedOverlay = nil
        iterationCount = 0
        errorMessage = nil
        statistics = nil
    }

    // MARK: - Seeding

    /// Replaces the seed, discards any refinement points, and runs the request.
    func setSeed(_ newSeed: SegmentationSeed) {
        seed = newSeed
        refinementPoints = []
        iterationCount = 0
        rebuildRequest()
        runSegmentation()
    }

    /// Seeds with a point at the centre of the image.
    ///
    /// Gives users who reach for the Analyze button an entry point that doesn't depend on
    /// discovering the tap interaction.
    func seedAtCenter() {
        setSeed(.point(CGPoint(x: 0.5, y: 0.5)))
    }

    /// Clears the seed, the refinement points and the mask, leaving the image in place.
    func resetSeed() {
        activeTask?.cancel()
        activeTask = nil
        request = nil
        seed = nil
        refinementPoints = []
        maskObservation = nil
        renderedOverlay = nil
        iterationCount = 0
        errorMessage = nil
    }

    // MARK: - Refinement

    /// Adds a refinement point at a normalized, top-left-origin location and re-runs.
    func addRefinementPoint(at location: CGPoint) {
        guard let request, seed != nil else { return }

        let point = RefinementPoint(location: location, polarity: pointPolarity)

        // Hand the point to the request first; only mirror it locally if it was accepted.
        // That keeps the request and `refinementPoints` consistent even if Vision's real
        // limit differs from `maxRefinementPoints`.
        do {
            try apply(point, to: request)
        } catch {
            errorMessage = "Vision won't accept more refinement points for this seed. Undo a point or reset the seed to keep going."
            return
        }

        refinementPoints.append(point)
        errorMessage = nil
        runSegmentation()
    }

    /// Removes the most recently added refinement point and re-runs.
    func undoLastPoint() {
        guard !refinementPoints.isEmpty else { return }
        refinementPoints.removeLast()
        rebuildRequest()
        runSegmentation()
    }

    /// Removes all refinement points, keeping the seed, and re-runs.
    func clearRefinementPoints() {
        guard !refinementPoints.isEmpty else { return }
        refinementPoints = []
        rebuildRequest()
        runSegmentation()
    }

    // MARK: - Asset Management

    /// Queries whether the downloadable model is present, without starting a download.
    func refreshAssetStatus() async {
        // `assetStatus` is an instance property but the asset is shared on disk, so a
        // throwaway probe is enough to answer the question before any seed exists.
        let probe = request ?? Self.makeProbeRequest()
        updateAssetState(from: await probe.assetStatus)
    }

    /// Downloads the segmentation model, reporting progress into ``downloadFraction``.
    func downloadAssets() async {
        let target = request ?? Self.makeProbeRequest()
        await download(using: target)
    }

    /// Ensures the model is on device, downloading it if necessary.
    ///
    /// Re-checks against the *live* request rather than trusting the earlier probe. That
    /// costs one cheap status query per run and is the safety net if the asset turns out
    /// to be tracked per instance rather than process-wide.
    @discardableResult
    func ensureAssetsReady() async -> Bool {
        let target = request ?? Self.makeProbeRequest()

        updateAssetState(from: await target.assetStatus)
        if assetState == .ready { return true }

        await download(using: target)
        return assetState == .ready
    }

    // MARK: - Private: Source Preparation

    /// Normalizes the selected image to `.up` orientation and caches its `CGImage`.
    ///
    /// This matters more here than in any other model in the app. `UIImage.cgImage` is the
    /// *unrotated* buffer while `Image(uiImage:)` renders the image *rotated*, so for a
    /// portrait photo from the camera or library, a tap on the subject would map to a
    /// completely different location in the buffer Vision sees — seeding the wrong object.
    private func prepareSource() {
        guard let image = selectedImage else {
            sourceImage = nil
            sourceCGImage = nil
            return
        }

        let normalized = Self.imageOrientedUp(image)
        sourceImage = normalized
        sourceCGImage = normalized.cgImage

        if sourceCGImage == nil {
            errorMessage = "That image couldn't be prepared for analysis."
        }
    }

    private static func imageOrientedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    // MARK: - Private: Request Lifecycle

    private static func makeProbeRequest() -> GenerateIterativeSegmentationRequest {
        GenerateIterativeSegmentationRequest(seedPoint: NormalizedPoint(x: 0.5, y: 0.5))
    }

    /// Builds a fresh request from the seed and replays the surviving refinement points.
    private func rebuildRequest() {
        guard let seed else {
            request = nil
            return
        }

        guard let fresh = makeRequest(for: seed) else {
            request = nil
            errorMessage = "That seed couldn't be prepared. Try a different one."
            return
        }

        var replayed: [RefinementPoint] = []
        for point in refinementPoints {
            do {
                try apply(point, to: fresh)
                replayed.append(point)
            } catch {
                // Hit Vision's cap during replay — keep the points that fit.
                break
            }
        }

        refinementPoints = replayed
        request = fresh
    }

    private func makeRequest(for seed: SegmentationSeed) -> GenerateIterativeSegmentationRequest? {
        let created: GenerateIterativeSegmentationRequest

        switch seed {
        case .point(let point):
            created = GenerateIterativeSegmentationRequest(seedPoint: Self.visionPoint(point))

        case .box(let rect):
            created = GenerateIterativeSegmentationRequest(seedBox: Self.visionRect(rect))

        case .scribble(let strokes):
            guard let cgImage = sourceCGImage,
                  let buffer = Self.makeScribbleBuffer(
                      strokes: strokes,
                      width: cgImage.width,
                      height: cgImage.height
                  )
            else { return nil }

            created = GenerateIterativeSegmentationRequest(seedScribbleBuffer: buffer)
        }

        created.qualityLevel = qualityLevel
        return created
    }

    private func apply(_ point: RefinementPoint, to request: GenerateIterativeSegmentationRequest) throws {
        let visionPoint = Self.visionPoint(point.location)

        switch point.polarity {
        case .include:
            try request.addIncludedPoint(visionPoint)
        case .exclude:
            try request.addExcludedPoint(visionPoint)
        }
    }

    // MARK: - Private: Coordinate Conversion

    /// Converts a normalized top-left point into Vision's bottom-left space.
    private static func visionPoint(_ point: CGPoint) -> NormalizedPoint {
        NormalizedPoint(x: point.x, y: 1 - point.y)
    }

    /// Converts a normalized top-left rect into Vision's bottom-left space.
    private static func visionRect(_ rect: CGRect) -> NormalizedRect {
        NormalizedRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }

    // MARK: - Private: Execution

    /// Schedules a run, replacing any run already in flight.
    private func runSegmentation() {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            await self?.performNow()
        }
    }

    private func performNow() async {
        guard let request, let cgImage = sourceCGImage, let imageSize = sourceImage?.size else { return }
        guard await ensureAssetsReady() else { return }

        isProcessing = true
        errorMessage = nil

        do {
            let (observation, tracker) = try await PerformanceTracker.measure {
                try await request.perform(on: cgImage, orientation: nil)
            }

            guard !Task.isCancelled else {
                isProcessing = false
                return
            }

            statistics = PerformanceStatistics(from: tracker)
            iterationCount += 1
            maskObservation = observation

            if let observation {
                renderedOverlay = await Self.renderOverlay(
                    observation: observation,
                    imageSize: imageSize,
                    tint: overlayColor
                )
            } else {
                renderedOverlay = nil
                errorMessage = "No object could be segmented from that seed. Try seeding somewhere else."
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Segmentation failed: \(error.localizedDescription)"
            }
        }

        isProcessing = false
    }

    private static func renderOverlay(
        observation: PixelBufferObservation,
        imageSize: CGSize,
        tint: UIColor
    ) async -> UIImage? {
        // Use `cgImage` rather than the new `pixelBuffer` property: `CVReadOnlyPixelBuffer`
        // only vends its buffer through a *synchronous* `withUnsafeBuffer`, so the async
        // renderer can't be awaited inside it, and letting the buffer escape would defeat
        // the read-only wrapper.
        guard let cgImage = try? observation.cgImage else { return nil }

        return await OverlayRenderer.renderMask(
            cgImage: cgImage,
            imageSize: imageSize,
            tintColor: tint
        )
    }

    // MARK: - Private: Asset Helpers

    private func updateAssetState(from status: DownloadableAssetsRequestStatus) {
        switch status {
        case .ready:
            assetState = .ready
            downloadFraction = 1
        case .notReady:
            assetState = .notReady
        case .downloading:
            assetState = .downloading
        case .error(let error):
            assetState = .failed(error.localizedDescription)
        @unknown default:
            assetState = .unknown
        }
    }

    private func download(using request: GenerateIterativeSegmentationRequest) async {
        guard assetState != .downloading else { return }

        assetState = .downloading
        downloadFraction = 0
        errorMessage = nil

        // `Subprogress` is `~Copyable` and the parameter is `consuming`, so it can't be
        // stored — it has to be created inline at the call site. `ProgressManager` is a
        // Sendable class and can be held onto for the duration of the download.
        let manager = ProgressManager(totalCount: 100)
        downloadIsIndeterminate = manager.isIndeterminate

        // This task inherits the main actor from the enclosing class, so the property
        // writes below need no hop.
        let mirror = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.downloadFraction = manager.fractionCompleted
                self.downloadIsIndeterminate = manager.isIndeterminate
                if manager.isFinished { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        do {
            try await request.downloadAssets(progress: manager.subprogress(assigningCount: 100))
            mirror.cancel()
            updateAssetState(from: await request.assetStatus)
        } catch {
            mirror.cancel()
            assetState = .failed(error.localizedDescription)
            errorMessage = "Couldn't download the segmentation model: \(error.localizedDescription)"
        }
    }

    // MARK: - Private: Scribble Rasterization

    /// Rasterizes freehand strokes into a single-channel mask buffer for scribble seeding.
    ///
    /// Strokes arrive in normalized top-left coordinates. A `CGContext` backed by a pixel
    /// buffer already addresses rows top-down, so the strokes map straight through without
    /// a vertical flip.
    /// - Parameters:
    ///   - strokes: Stroke paths in normalized top-left coordinates.
    ///   - width: Pixel width of the source image.
    ///   - height: Pixel height of the source image.
    /// - Returns: A read-only buffer marking the scribbled region, or `nil` on failure.
    private static func makeScribbleBuffer(
        strokes: [[CGPoint]],
        width: Int,
        height: Int
    ) -> CVReadOnlyPixelBuffer? {
        guard width > 0, height > 0, strokes.contains(where: { !$0.isEmpty }) else { return nil }

        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attributes,
            &buffer
        ) == kCVReturnSuccess, let buffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        if let context {
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineWidth(max(CGFloat(min(width, height)) * 0.02, 4))
            context.setLineCap(.round)
            context.setLineJoin(.round)

            for stroke in strokes where !stroke.isEmpty {
                let scaled = stroke.map {
                    CGPoint(x: $0.x * CGFloat(width), y: $0.y * CGFloat(height))
                }

                context.beginPath()
                context.move(to: scaled[0])

                if scaled.count == 1 {
                    // A single tap still needs to mark pixels; a round cap on a
                    // zero-length segment paints a dot.
                    context.addLine(to: scaled[0])
                } else {
                    for point in scaled.dropFirst() {
                        context.addLine(to: point)
                    }
                }

                context.strokePath()
            }
        }

        CVPixelBufferUnlockBaseAddress(buffer, [])

        guard context != nil else { return nil }

        return CVReadOnlyPixelBuffer(unsafeBuffer: buffer)
    }
}

#endif
