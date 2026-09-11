import CoreLocation
import Foundation

/// One recorded fix. Codable for on-disk persistence (JSON lines).
struct TrackPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    let verticalAccuracy: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        timestamp = location.timestamp
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
    }
}

/// Live session statistics. Distance/elevation in meters, duration in seconds.
struct TrackStats: Equatable {
    var duration: TimeInterval = 0
    var distance: CLLocationDistance = 0
    var elevationGain: CLLocationDistance = 0

    /// Average pace, seconds per kilometer. Nil until enough distance to matter.
    var paceSecondsPerKilometer: Double? {
        guard distance > 10, duration > 0 else { return nil }
        return duration / (distance / 1000)
    }
}

/// Persistent session metadata (kept separate from the point stream).
struct TrackSessionMeta: Codable {
    var id: UUID
    var startDate: Date
    var isRecording: Bool
    /// Active recording time completed before the current segment (handles pauses).
    var accumulatedActiveTime: TimeInterval
    /// When the current recording segment began (nil while paused).
    var lastResumeDate: Date?

    /// Total active duration as of `now`.
    func activeDuration(asOf now: Date = Date()) -> TimeInterval {
        var total = accumulatedActiveTime
        if isRecording, let resume = lastResumeDate {
            total += now.timeIntervalSince(resume)
        }
        return total
    }
}
