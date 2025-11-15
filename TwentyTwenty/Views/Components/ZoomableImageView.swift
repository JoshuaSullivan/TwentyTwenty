import SwiftUI
import UIKit

/// A zoomable image view that supports double-tap to toggle between aspect-fit and 100% zoom
struct ZoomableImageView: UIViewRepresentable {
    let baseImage: UIImage
    let overlayImage: UIImage?
    let showOverlay: Bool
    let overlayOpacity: Double
    let overlayTint: Color
    let resetZoom: Int

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let containerView = UIView()
        containerView.tag = 100
        containerView.backgroundColor = .clear
        scrollView.addSubview(containerView)

        let imageView = UIImageView()
        imageView.tag = 101
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        containerView.addSubview(imageView)

        let overlayImageView = UIImageView()
        overlayImageView.tag = 102
        overlayImageView.contentMode = .scaleAspectFit
        overlayImageView.backgroundColor = .clear
        containerView.addSubview(overlayImageView)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let containerView = scrollView.viewWithTag(100),
              let imageView = containerView.viewWithTag(101) as? UIImageView,
              let overlayImageView = containerView.viewWithTag(102) as? UIImageView else {
            return
        }

        let imageChanged = imageView.image != baseImage
        let shouldReset = context.coordinator.lastResetValue != resetZoom

        imageView.image = baseImage
        overlayImageView.image = overlayImage
        overlayImageView.isHidden = !showOverlay || overlayImage == nil
        overlayImageView.alpha = overlayOpacity

        if let overlayImg = overlayImage, showOverlay {
            overlayImageView.tintColor = UIColor(overlayTint)
            overlayImageView.image = overlayImg.withRenderingMode(.alwaysTemplate)
        }

        let imageSize = baseImage.size
        let scrollViewSize = scrollView.bounds.size

        guard scrollViewSize.width > 0 && scrollViewSize.height > 0 && imageSize.width > 0 && imageSize.height > 0 else { return }

        let widthScale = scrollViewSize.width / imageSize.width
        let heightScale = scrollViewSize.height / imageSize.height
        let aspectFitScale = min(widthScale, heightScale)

        containerView.frame = CGRect(origin: .zero, size: imageSize)
        imageView.frame = CGRect(origin: .zero, size: imageSize)
        overlayImageView.frame = CGRect(origin: .zero, size: imageSize)

        scrollView.minimumZoomScale = aspectFitScale
        scrollView.maximumZoomScale = 1.0
        scrollView.contentSize = imageSize

        if imageChanged || shouldReset {
            scrollView.zoomScale = aspectFitScale
            context.coordinator.lastResetValue = resetZoom
        }

        centerScrollViewContents(scrollView)

        context.coordinator.scrollView = scrollView
        context.coordinator.aspectFitScale = aspectFitScale
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func centerScrollViewContents(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        var aspectFitScale: CGFloat = 1.0
        var lastResetValue: Int = 0

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerScrollViewContents(scrollView)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }

            if scrollView.zoomScale > aspectFitScale {
                scrollView.setZoomScale(aspectFitScale, animated: true)
            } else {
                let tapPoint = gesture.location(in: scrollView.viewWithTag(100))
                let newZoomScale: CGFloat = 1.0

                let scrollViewSize = scrollView.bounds.size
                let width = scrollViewSize.width / newZoomScale
                let height = scrollViewSize.height / newZoomScale
                let x = tapPoint.x - (width / 2.0)
                let y = tapPoint.y - (height / 2.0)

                let rectToZoomTo = CGRect(x: x, y: y, width: width, height: height)
                scrollView.zoom(to: rectToZoomTo, animated: true)
            }
        }

        private func centerScrollViewContents(_ scrollView: UIScrollView) {
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }
    }
}
