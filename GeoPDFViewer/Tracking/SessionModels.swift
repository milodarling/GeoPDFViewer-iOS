import CoreLocation
import Foundation

/// Lightweight description of a saved session, stored separately from its point
/// stream so the sessions list loads without reading every fix.
struct SessionSummary: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distance: CLLocationDistance
    let elevationGain: CLLocationDistance
    let pointCount: Int

    var paceSecondsPerKilometer: Double? {
        guard distance > 10, duration > 0 else { return nil }
        return duration / (distance / 1000)
    }
}
