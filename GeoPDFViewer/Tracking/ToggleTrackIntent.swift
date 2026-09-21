import AppIntents
import Foundation

extension Notification.Name {
    /// Posted by the Live Activity's pause/resume button; observed by the
    /// app-scoped `TrackRecorder`.
    static let toggleTrackRecording = Notification.Name("toggleTrackRecording")
}

/// Backs the pause/resume button in the Live Activity. `LiveActivityIntent`
/// runs in the app's process, so posting a local notification reaches the
/// running `TrackRecorder` (the app is launched in the background if needed).
///
/// Kept free of any app-only symbols so it also compiles into the widget
/// extension, which references it for `Button(intent:)`.
@available(iOS 17.0, *)
struct ToggleTrackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Tracking"

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .toggleTrackRecording, object: nil)
        return .result()
    }
}
