import CoreLocation
import MapKit
import SwiftUI

/// A tracking session on the built-in Apple map (no GeoPDF). Shows the user's
/// location and the in-progress route, with the same HUD/controls as the PDF
/// map — so a session can be recorded without opening a document.
struct MapOnlyScreen: View {
    @EnvironmentObject private var recorder: TrackRecorder

    var body: some View {
        LiveRouteMapView(coordinates: recorder.points.map(\.coordinate),
                         userLocation: recorder.latest?.coordinate)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) { TrackingHUD(recorder: recorder) }
            .navigationTitle("Apple Maps")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { recorder.startViewing() }
            .onDisappear { recorder.stopViewing() }
    }
}

/// A live MKMapView showing the user's location and the recorded route so far.
/// Redraws the polyline as new fixes arrive (the parent re-renders whenever the
/// recorder publishes a new `latest`/`stats`).
struct LiveRouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let userLocation: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
        context.coordinator.centerIfNeeded(mapView, on: userLocation)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var hasCentered = false

        /// Center on the user once, as a fallback before follow-mode kicks in.
        func centerIfNeeded(_ mapView: MKMapView, on coordinate: CLLocationCoordinate2D?) {
            guard !hasCentered, let coordinate else { return }
            hasCentered = true
            mapView.setRegion(
                MKCoordinateRegion(center: coordinate,
                                   latitudinalMeters: 1000, longitudinalMeters: 1000),
                animated: false)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            return renderer
        }
    }
}
