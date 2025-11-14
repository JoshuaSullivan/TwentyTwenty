import SwiftUI
import PhotosUI
import UIKit

/// SwiftUI view for picking images from camera or photo library
struct ImagePickerView: View {
    /// Binding to the selected image
    @Binding var selectedImage: UIImage?

    /// Whether to show the camera or photo library
    let sourceType: UIImagePickerController.SourceType

    /// Presentation mode for dismissing the view
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if sourceType == .camera {
            CameraPickerRepresentable(selectedImage: $selectedImage, dismiss: dismiss)
        } else {
            PhotoLibraryPickerView(selectedImage: $selectedImage)
        }
    }
}

// MARK: - Photo Library Picker (Modern PhotosUI)

/// Modern photo library picker using PhotosUI
struct PhotoLibraryPickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images
        ) {
            Text("Select Photo")
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Camera Picker (UIImagePickerController)

/// Camera picker using UIImagePickerController
struct CameraPickerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let dismiss: DismissAction

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImage: $selectedImage, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var selectedImage: UIImage?
        let dismiss: DismissAction

        init(selectedImage: Binding<UIImage?>, dismiss: DismissAction) {
            self._selectedImage = selectedImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                selectedImage = image
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
