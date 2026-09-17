import PhotosUI
import SwiftUI

/// The three ways to set a profile photo: take a picture, upload from the
/// library, or fall back to a monogram avatar.
struct PhotoSourceSheet: View {
    var showsAvatarOption = true
    let onPhoto: (Data) -> Void
    var onAvatar: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCamera = false
    @State private var pickerItem: PhotosPickerItem?

    private var isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    /// Explicit init: the synthesized memberwise initializer is private
    /// (private stored properties), which breaks @testable builds.
    init(
        showsAvatarOption: Bool = true,
        onPhoto: @escaping (Data) -> Void,
        onAvatar: @escaping () -> Void = {}
    ) {
        self.showsAvatarOption = showsAvatarOption
        self.onPhoto = onPhoto
        self.onAvatar = onAvatar
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                sourceRow(
                    symbol: "camera.fill",
                    title: "Take a Photo",
                    caption: isCameraAvailable ? "Open the camera" : "Camera isn't available on this device",
                    isEnabled: isCameraAvailable
                ) {
                    isShowingCamera = true
                }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    sourceRow(
                        symbol: "photo.on.rectangle",
                        title: "Upload from Library",
                        caption: "Pick an existing photo",
                        isEnabled: true
                    ) {}
                }
                .buttonStyle(.pressable)

                if showsAvatarOption {
                    sourceRow(
                        symbol: "person.crop.artframe",
                        title: "Create an Avatar",
                        caption: "Your initials on your card finish",
                        isEnabled: true
                    ) {
                        onAvatar()
                        dismiss()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 6)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Set Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { data in
                onPhoto(data)
                dismiss()
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let processed = ProfileImage.processedData(from: data) {
                    onPhoto(processed)
                    dismiss()
                }
            }
        }
    }

    private func sourceRow(
        symbol: String,
        title: String,
        caption: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isEnabled ? Theme.accent : Theme.textTertiary)
                    .frame(width: 42, height: 42)
                    .background(
                        isEnabled ? Theme.accent.opacity(0.14) : Theme.surfaceHigh,
                        in: .circle
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isEnabled ? Theme.textPrimary : Theme.textTertiary)
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .panel()
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
    }
}

/// Camera capture wrapper used by the photo source sheet.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85),
               let processed = ProfileImage.processedData(from: data) {
                parent.onCapture(processed)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Downscales picked images so they persist comfortably.
enum ProfileImage {
    static func processedData(from data: Data, maxDimension: CGFloat = 720) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
