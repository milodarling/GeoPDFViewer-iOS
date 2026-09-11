import AVFoundation
import SwiftUI
import UIKit

/// Full-screen camera QR scanner. Calls `onResult` exactly once with the decoded
/// string (or an error), then stops the session. The camera is unavailable in
/// the iOS Simulator, where this reports `.cameraUnavailable`.
struct QRScannerView: UIViewControllerRepresentable {
    enum ScanError: LocalizedError {
        case cameraUnavailable
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "No camera is available on this device."
            case .permissionDenied: return "Camera access was denied. Enable it in Settings to scan QR codes."
            }
        }
    }

    let onResult: (Result<String, Error>) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onResult = onResult
        return controller
    }

    func updateUIViewController(_ controller: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((Result<String, Error>) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                granted ? self.configureSession() : self.finish(.failure(QRScannerView.ScanError.permissionDenied))
            }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            finish(.failure(QRScannerView.ScanError.cameraUnavailable))
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            finish(.failure(QRScannerView.ScanError.cameraUnavailable))
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        // startRunning() blocks; keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr, let value = object.stringValue else { return }
        finish(.success(value))
    }

    private func finish(_ result: Result<String, Error>) {
        guard !didFinish else { return }
        didFinish = true
        if session.isRunning { session.stopRunning() }
        onResult?(result)
    }
}
