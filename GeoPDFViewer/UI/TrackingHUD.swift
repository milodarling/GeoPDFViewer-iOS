import SwiftUI

/// Floating stats panel + recording controls, overlaid on the map.
struct TrackingHUD: View {
    @ObservedObject var recorder: TrackRecorder
    @State private var confirmingDiscard = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                stat("Time", timeString)
                divider
                stat("Distance", distanceString)
                divider
                stat("Elev ↑", elevationString)
                divider
                stat("Pace", paceString)
            }
            controls
            if recorder.authorizationDenied {
                Text("Location access is off — enable it in Settings to track.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var divider: some View { Divider().frame(height: 34) }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controls: some View {
        switch recorder.state {
        case .idle:
            Button { recorder.start() } label: {
                Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .recording:
            HStack {
                Button { recorder.pause() } label: {
                    Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                Button { recorder.finish() } label: {
                    Label("Finish", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        case .paused:
            HStack {
                Button { recorder.start() } label: {
                    Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button { recorder.finish() } label: {
                    Label("Finish", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) { confirmingDiscard = true } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
            .confirmationDialog("Discard this session?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { recorder.reset() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Formatting

    private var timeString: String { StatFormatting.duration(recorder.stats.duration) }
    private var distanceString: String { StatFormatting.distance(recorder.stats.distance) }
    private var elevationString: String { StatFormatting.elevation(recorder.stats.elevationGain) }
    private var paceString: String { StatFormatting.pace(secondsPerKilometer: recorder.stats.paceSecondsPerKilometer) }
}
