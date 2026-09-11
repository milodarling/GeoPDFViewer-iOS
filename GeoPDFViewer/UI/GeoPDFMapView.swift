import SwiftUI

/// SwiftUI wrapper around `GeoPDFMapViewController`.
///
///     GeoPDFMapView(url: myGeoPDFURL)
///
/// Reopens automatically when `url` changes.
public struct GeoPDFMapView: UIViewControllerRepresentable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> GeoPDFMapViewController {
        GeoPDFMapViewController()
    }

    public func updateUIViewController(_ controller: GeoPDFMapViewController, context: Context) {
        controller.open(url: url)
    }
}
