import SwiftUI
import UIKit

/// View for selecting a rectangle to track by drawing on the first frame
struct RectangleSelectionView: View {
    let firstFrame: UIImage
    let onSelection: ((topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint)) -> Void

    @State private var selectedCorners: (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint)?
    @State private var currentCorner: Int?
    @State private var draggedCorners: [CGPoint] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Rectangle to Track")
                .font(.headline)

            Text("Tap four corners of a rectangle in order: top-left, top-right, bottom-right, bottom-left")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: firstFrame)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    // Draw selected corners and lines
                    if !draggedCorners.isEmpty {
                        Path { path in
                            for (index, corner) in draggedCorners.enumerated() {
                                if index == 0 {
                                    path.move(to: corner)
                                } else {
                                    path.addLine(to: corner)
                                }
                            }
                            // Close the path if we have all 4 corners
                            if draggedCorners.count == 4 {
                                path.closeSubpath()
                            }
                        }
                        .stroke(Color.blue, lineWidth: 2)

                        ForEach(Array(draggedCorners.enumerated()), id: \.offset) { index, corner in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                                .position(corner)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                        .position(corner)
                                )
                                .overlay(
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .position(corner)
                                )
                        }
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

            HStack(spacing: 12) {
                if !draggedCorners.isEmpty {
                    Button {
                        draggedCorners.removeLast()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if draggedCorners.count == 4 {
                    Button {
                        if let corners = selectedCorners {
                            onSelection(corners)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Use This Rectangle")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
    }

    private func handleTap(at location: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
        // Don't allow more than 4 corners
        guard draggedCorners.count < 4 else { return }

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

        // Store the view-space location for drawing
        draggedCorners.append(location)

        // Update the normalized corners when we have all 4
        if draggedCorners.count == 4 {
            // Convert all corners to normalized coordinates
            var normalizedCorners: [CGPoint] = []
            for corner in draggedCorners {
                let x = (corner.x - imageFrame.minX) / imageFrame.width
                let y = (corner.y - imageFrame.minY) / imageFrame.height
                normalizedCorners.append(CGPoint(
                    x: max(0, min(1, x)),
                    y: max(0, min(1, y))
                ))
            }

            selectedCorners = (
                topLeft: normalizedCorners[0],
                topRight: normalizedCorners[1],
                bottomRight: normalizedCorners[2],
                bottomLeft: normalizedCorners[3]
            )
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedRectangle: (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint)?

        var body: some View {
            if let sampleImage = UIImage(systemName: "photo") {
                RectangleSelectionView(firstFrame: sampleImage) { rectangle in
                    selectedRectangle = rectangle
                    print("Selected rectangle: \(rectangle)")
                }
            }
        }
    }

    return PreviewWrapper()
}
