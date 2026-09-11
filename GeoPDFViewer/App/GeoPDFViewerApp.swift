import SwiftUI

@main
struct GeoPDFViewerApp: App {
    // App-scoped so a tracking session survives navigation and is restored on
    // launch (see TrackRecorder / TrackStore).
    @StateObject private var recorder = TrackRecorder()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(recorder)
        }
    }
}
