import SwiftUI
import UIKit

/// View for selecting an object to track by tapping on the first frame
struct ObjectSelectionView: View {
    let firstFrame: UIImage
    let onSelection: (CGRect) -> Void

    @State private var selectedPoint: CGPoint?
    @State private var selectedRect: CGRect?

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Object to Track")
                .font(.headline)

            Text("Tap on the object you want to track in the first frame")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Image with tap gesture
            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: firstFrame)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    // Show selection indicator
                    if let point = selectedPoint {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .position(point)
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                                    .frame(width: 100, height: 100)
                                    .position(point)
                            )
                    }

                    // Invisible tap overlay
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, in: geometry.size, imageSize: firstFrame.size)
                        }
                }
            }
            .aspectRatio(firstFrame.size, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )

            if selectedPoint != nil {
                Button {
                    if let rect = selectedRect {
                        onSelection(rect)
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Use This Selection")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }

    private func handleTap(at location: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
        selectedPoint = location

        // Calculate the image dimensions within the view (scaledToFit)
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        var imageFrame: CGRect

        if imageAspect > viewAspect {
            // Image is wider - fit to width
            let displayHeight = viewSize.width / imageAspect
            let yOffset = (viewSize.height - displayHeight) / 2
            imageFrame = CGRect(x: 0, y: yOffset, width: viewSize.width, height: displayHeight)
        } else {
            // Image is taller - fit to height
            let displayWidth = viewSize.height * imageAspect
            let xOffset = (viewSize.width - displayWidth) / 2
            imageFrame = CGRect(x: xOffset, y: 0, width: displayWidth, height: viewSize.height)
        }

        // Convert tap location to normalized coordinates (0-1)
        let relativeX = (location.x - imageFrame.minX) / imageFrame.width
        let relativeY = (location.y - imageFrame.minY) / imageFrame.height

        // Clamp to valid range
        let clampedX = max(0, min(1, relativeX))
        let clampedY = max(0, min(1, relativeY))

        // Create a bounding box centered on the tap point (15% of image size)
        let boxSize: CGFloat = 0.15 // 15% of image dimensions
        let normalizedRect = CGRect(
            x: max(0, min(1 - boxSize, clampedX - boxSize / 2)),
            y: max(0, min(1 - boxSize, clampedY - boxSize / 2)),
            width: boxSize,
            height: boxSize
        )

        selectedRect = normalizedRect
    }
}

/// UIKit-based view for drawing a bounding box (alternative implementation)
struct DrawableImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var selectedRect: CGRect?

    func makeUIView(context: Context) -> DrawableImageUIView {
        let view = DrawableImageUIView()
        view.image = image
        view.onRectSelected = { rect in
            selectedRect = rect
        }
        return view
    }

    func updateUIView(_ uiView: DrawableImageUIView, context: Context) {
        uiView.image = image
    }
}

/// UIKit view that allows drawing a bounding box
class DrawableImageUIView: UIView {
    var image: UIImage?
    var onRectSelected: ((CGRect) -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?

    private let imageView = UIImageView()
    private let overlayView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        overlayView.backgroundColor = .clear
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        overlayView.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: overlayView)

        switch gesture.state {
        case .began:
            startPoint = location
            currentRect = nil

        case .changed:
            if let start = startPoint {
                let width = abs(location.x - start.x)
                let height = abs(location.y - start.y)
                let x = min(start.x, location.x)
                let y = min(start.y, location.y)

                currentRect = CGRect(x: x, y: y, width: width, height: height)
                overlayView.setNeedsDisplay()
            }

        case .ended:
            if let rect = currentRect, imageView.image?.size != nil {
                // Convert to normalized coordinates
                let imageFrame = imageView.frame
                let normalizedRect = CGRect(
                    x: (rect.origin.x - imageFrame.origin.x) / imageFrame.width,
                    y: (rect.origin.y - imageFrame.origin.y) / imageFrame.height,
                    width: rect.width / imageFrame.width,
                    height: rect.height / imageFrame.height
                )
                onRectSelected?(normalizedRect)
            }
            startPoint = nil
            currentRect = nil
            overlayView.setNeedsDisplay()

        default:
            break
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext(),
              let rect = currentRect else { return }

        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.stroke(rect)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedRect: CGRect?

        var body: some View {
            if let sampleImage = UIImage(systemName: "photo") {
                ObjectSelectionView(firstFrame: sampleImage) { rect in
                    selectedRect = rect
                    print("Selected rect: \(rect)")
                }
            }
        }
    }

    return PreviewWrapper()
}
