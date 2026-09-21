import ActivityKit
import SwiftUI
import WidgetKit

/// The tracking Live Activity: a lock-screen / Notification Center banner and
/// the Dynamic Island, showing time, distance, elevation, and pace, plus a
/// pause/resume button (interactive on iOS 17+).
@available(iOS 16.2, *)
struct TrackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.5))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    labeled("Time") { TimeView(state: context.state) }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    labeled("Dist") { Text(StatFormatting.distance(context.state.distance)) }
                }
                DynamicIslandExpandedRegion(.center) {
                    labeled("Elev ↑") { Text(StatFormatting.elevation(context.state.elevationGain)) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        labeled("Pace") {
                            Text(StatFormatting.pace(secondsPerKilometer: context.state.paceSecondsPerKilometer))
                        }
                        Spacer()
                        ToggleButton(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isRunning ? "figure.walk" : "pause.fill")
            } compactTrailing: {
                TimeView(state: context.state).monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isRunning ? "figure.walk" : "pause.fill")
            }
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content().font(.system(.headline, design: .rounded)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Live-updating time: counts up while recording, frozen while paused.
@available(iOS 16.2, *)
struct TimeView: View {
    let state: TrackActivityAttributes.ContentState

    var body: some View {
        if state.isRunning {
            Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
        } else {
            Text(StatFormatting.duration(state.frozenDuration))
        }
    }
}

/// Pause/resume control. Interactive via App Intent on iOS 17+; on iOS 16 it
/// renders as a status label (buttons in Live Activities require iOS 17).
@available(iOS 16.2, *)
struct ToggleButton: View {
    let state: TrackActivityAttributes.ContentState

    var body: some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleTrackIntent()) {
                Label(state.isRunning ? "Pause" : "Resume",
                      systemImage: state.isRunning ? "pause.fill" : "play.fill")
            }
            .tint(state.isRunning ? .orange : .green)
        } else {
            Label(state.isRunning ? "Recording" : "Paused",
                  systemImage: state.isRunning ? "figure.walk" : "pause.fill")
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 16.2, *)
struct LockScreenView: View {
    let state: TrackActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                stat("Time") { TimeView(state: state) }
                divider
                stat("Distance") { Text(StatFormatting.distance(state.distance)) }
                divider
                stat("Elev ↑") { Text(StatFormatting.elevation(state.elevationGain)) }
                divider
                stat("Pace") {
                    Text(StatFormatting.pace(secondsPerKilometer: state.paceSecondsPerKilometer))
                }
            }
            if #available(iOS 17.0, *) {
                Button(intent: ToggleTrackIntent()) {
                    Label(state.isRunning ? "Pause" : "Resume",
                          systemImage: state.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(state.isRunning ? .orange : .green)
            }
        }
    }

    private var divider: some View { Divider().frame(height: 34).overlay(Color.white.opacity(0.2)) }

    @ViewBuilder
    private func stat<Content: View>(_ label: String, @ViewBuilder _ value: () -> Content) -> some View {
        VStack(spacing: 2) {
            value()
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
