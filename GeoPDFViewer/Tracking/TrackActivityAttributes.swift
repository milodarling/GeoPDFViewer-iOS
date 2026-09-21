import ActivityKit
import Foundation

/// Shared between the app (which starts/updates the Live Activity) and the
/// widget extension (which renders it). Carries the live session stats.
@available(iOS 16.1, *)
struct TrackActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var distance: Double            // meters
        var elevationGain: Double       // meters
        var paceSecondsPerKilometer: Double?
        var isRunning: Bool
        /// Effective start for a live `.timer` display: `now - activeDuration`
        /// at update time, so the lock-screen clock counts up while recording.
        var timerStart: Date
        /// Active duration to show frozen while paused.
        var frozenDuration: TimeInterval
    }
}
