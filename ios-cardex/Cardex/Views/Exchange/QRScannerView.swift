import SwiftUI
import AVFoundation

/// Live camera QR scanner for real card exchanges. Runs the actual
/// AVFoundation pipeline (the cloud simulator injects a camera device);
/// handles permission denial and missing hardware with honest states.
struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {
        controller.onCode = onCode
    }
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastCode: String?
    private var lastCodeAt = Date.distantPast
    private let sessionQueue = DispatchQueue(label: "cardex.scanner.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermission()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    if granted { self?.setupCamera() } else { self?.showDenied() }
                }
            }
        default:
            showDenied()
        }
    }

    private func setupCamera() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device, let input = try? AVCaptureDeviceInput(device: device) else {
            showUnavailable()
            return
        }

        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    private func showDenied() {
        showMessage(
            title: "Camera access is off",
            body: "Cardex needs the camera to scan cards. Enable it in Settings.",
            settingsLink: true,
        )
    }

    private func showUnavailable() {
        showMessage(
            title: "No camera available",
            body: "This device can't scan cards. Ask them to show their code instead.",
            settingsLink: false,
        )
    }

    private func showMessage(title: String, body: String, settingsLink: Bool) {
        let stack = UIStackView(arrangedSubviews: [
            label(title, size: 18, weight: .semibold),
            label(body, size: 14, weight: .regular),
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
        ])

        if settingsLink {
            let button = UIButton(type: .system)
            button.setTitle("Open Settings", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            button.backgroundColor = UIColor(red: 0x6C / 255, green: 0x7B / 255, blue: 0xFF / 255, alpha: 1)
            button.layer.cornerRadius = 12
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addAction(UIAction { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }, for: .touchUpInside)
            view.addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
                button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                button.heightAnchor.constraint(equalToConstant: 44),
                button.widthAnchor.constraint(equalToConstant: 180),
            ])
        }
    }

    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection,
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else { return }

        // Debounce repeated detections of the same code.
        if value == lastCode, Date().timeIntervalSince(lastCodeAt) < 3 { return }
        lastCode = value
        lastCodeAt = Date()
        onCode?(value)
    }
}
