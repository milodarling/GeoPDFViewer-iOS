import SwiftUI

/// SwiftUI wrapper around `GeoPDFMapViewController`. Reopens when `url` changes.
struct GeoPDFMapView: UIViewControllerRepresentable {
    let url: URL
    let recorder: TrackRecorder

    func makeUIViewController(context: Context) -> GeoPDFMapViewController {
        let controller = GeoPDFMapViewController()
        controller.recorder = recorder
        return controller
    }

    func updateUIViewController(_ controller: GeoPDFMapViewController, context: Context) {
        controller.open(url: url)
    }
}
