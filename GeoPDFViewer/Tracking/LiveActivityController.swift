import ActivityKit
import Foundation

/// App-side manager for the tracking Live Activity: starts one when recording
/// begins, updates it as stats change, and ends it when the session stops.
@available(iOS 16.2, *)
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<TrackActivityAttributes>?

    private func state(distance: Double, elevationGain: Double,
                       paceSecondsPerKilometer: Double?, activeDuration: TimeInterval,
                       isRunning: Bool) -> TrackActivityAttributes.ContentState {
        TrackActivityAttributes.ContentState(
            distance: distance,
            elevationGain: elevationGain,
            paceSecondsPerKilometer: paceSecondsPerKilometer,
            isRunning: isRunning,
            timerStart: Date().addingTimeInterval(-activeDuration),
            frozenDuration: activeDuration)
    }

    /// Start a new Live Activity, adopting an existing one if the app was
    /// relaunched while a session was live (avoids duplicates).
    func startOrUpdate(distance: Double, elevationGain: Double,
                       paceSecondsPerKilometer: Double?, activeDuration: TimeInterval,
                       isRunning: Bool) {
        if activity == nil {
            activity = Activity<TrackActivityAttributes>.activities.first
        }
        if activity != nil {
            update(distance: distance, elevationGain: elevationGain,
                   paceSecondsPerKilometer: paceSecondsPerKilometer,
                   activeDuration: activeDuration, isRunning: isRunning)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = state(distance: distance, elevationGain: elevationGain,
                            paceSecondsPerKilometer: paceSecondsPerKilometer,
                            activeDuration: activeDuration, isRunning: isRunning)
        activity = try? Activity.request(
            attributes: TrackActivityAttributes(),
            content: ActivityContent(state: content, staleDate: nil))
    }

    func update(distance: Double, elevationGain: Double,
                paceSecondsPerKilometer: Double?, activeDuration: TimeInterval,
                isRunning: Bool) {
        guard let activity else { return }
        let content = state(distance: distance, elevationGain: elevationGain,
                            paceSecondsPerKilometer: paceSecondsPerKilometer,
                            activeDuration: activeDuration, isRunning: isRunning)
        Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
