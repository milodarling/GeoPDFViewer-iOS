import CoreLocation
import MapKit
import SwiftUI

/// One saved session: its route on a MapKit map (so it's viewable without the
/// original GeoPDF), plus summary stats.
struct SessionDetailView: View {
    let summary: SessionSummary
    @State private var coordinates: [CLLocationCoordinate2D] = []

    var body: some View {
        VStack(spacing: 0) {
            RouteMapView(coordinates: coordinates)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 320)

            statsGrid
                .padding()
            Spacer(minLength: 0)
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            coordinates = SessionLibrary.shared.points(for: summary.id).map(\.coordinate)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 0) {
            stat("Time", StatFormatting.duration(summary.duration))
            Divider().frame(height: 40)
            stat("Distance", StatFormatting.distance(summary.distance))
            Divider().frame(height: 40)
            stat("Elev ↑", StatFormatting.elevation(summary.elevationGain))
            Divider().frame(height: 40)
            stat("Pace", StatFormatting.pace(secondsPerKilometer: summary.paceSecondsPerKilometer))
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// An MKMapView that draws a route polyline and frames it.
struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        guard coordinates.count > 1 else { return }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: false)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
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
