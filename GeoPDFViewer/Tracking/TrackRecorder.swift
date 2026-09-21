import Combine
import CoreLocation

/// Owns location updates and the recording session: accumulates the traveled
/// path, computes live stats, and persists everything so a session survives
/// backgrounding and app termination. App-scoped (one instance, injected via
/// the environment) so it keeps running as the user navigates.
final class TrackRecorder: NSObject, ObservableObject {
    enum State { case idle, recording, paused }

    @Published private(set) var state: State = .idle
    @Published private(set) var stats = TrackStats()
    @Published private(set) var latest: CLLocation?
    @Published private(set) var authorizationDenied = false

    /// The recorded path. Mutated and read on the main thread only
    /// (delegate callbacks, the map overlay's display link, and the UI).
    private(set) var points: [TrackPoint] = []

    private let manager = CLLocationManager()
    private let store = TrackStore.shared
    private var meta: TrackSessionMeta?

    private var lastAccepted: CLLocation?
    private var gainReferenceAltitude: Double?
    private var displayTimer: Timer?
    private var viewers = 0

    /// Set on init so the Live Activity's pause/resume intent (which runs in
    /// this process) can reach the app-scoped recorder via a notification.
    static private(set) weak var shared: TrackRecorder?

    /// Fixes worse than this (meters) are ignored for path/stats.
    private let horizontalAccuracyLimit: CLLocationDistance = 50
    /// Minimum upward change (meters) counted toward elevation gain (noise deadband).
    private let elevationDeadband: CLLocationDistance = 1.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        TrackRecorder.shared = self
        NotificationCenter.default.addObserver(
            forName: .toggleTrackRecording, object: nil, queue: .main) { [weak self] _ in
            self?.toggle()
        }
        restoreSession()
    }

    /// Toggle recording ⇄ paused (driven by the Live Activity button).
    func toggle() {
        switch state {
        case .recording: pause()
        case .paused, .idle: start()
        }
    }

    // MARK: - Viewing (the location dot is shown whenever a map is on screen)

    func startViewing() {
        viewers += 1
        requestAuthorizationIfNeeded()
        manager.startUpdatingLocation()
    }

    func stopViewing() {
        viewers = max(0, viewers - 1)
        if viewers == 0, state != .recording {
            manager.stopUpdatingLocation()
        }
    }

    // MARK: - Recording control

    /// Start a new session, or resume a paused one.
    func start() {
        requestAuthorizationIfNeeded()
        let now = Date()
        if state == .paused, var existing = meta {
            existing.isRecording = true
            existing.lastResumeDate = now
            meta = existing
        } else {
            points = []
            lastAccepted = nil
            gainReferenceAltitude = nil
            stats = TrackStats()
            store.clear()
            meta = TrackSessionMeta(id: UUID(), startDate: now, isRecording: true,
                                    accumulatedActiveTime: 0, lastResumeDate: now)
        }
        state = .recording
        persistMeta()
        enableBackgroundUpdates(true)
        manager.startUpdatingLocation()
        startDisplayTimer()
        recomputeDuration()
        beginOrUpdateLiveActivity()
    }

    func pause() {
        guard state == .recording, var current = meta else { return }
        current.accumulatedActiveTime += Date().timeIntervalSince(current.lastResumeDate ?? Date())
        current.isRecording = false
        current.lastResumeDate = nil
        meta = current
        state = .paused
        persistMeta()
        enableBackgroundUpdates(false)
        stopDisplayTimer()
        if viewers == 0 { manager.stopUpdatingLocation() }
        recomputeDuration()
        refreshLiveActivity()
    }

    /// End the current session and save it to the library, then clear the active
    /// session. Pauses first if still recording so the final stats are frozen.
    func finish() {
        if state == .recording { pause() }
        if let meta, !points.isEmpty {
            let summary = SessionSummary(
                id: meta.id,
                title: SessionLibrary.defaultTitle(for: meta.startDate),
                startDate: meta.startDate,
                endDate: Date(),
                duration: stats.duration,
                distance: stats.distance,
                elevationGain: stats.elevationGain,
                pointCount: points.count)
            SessionLibrary.shared.save(summary: summary, points: points)
        }
        reset()
    }

    /// Discard the active session without saving.
    func reset() {
        state = .idle
        meta = nil
        points = []
        lastAccepted = nil
        gainReferenceAltitude = nil
        stats = TrackStats()
        store.clear()
        enableBackgroundUpdates(false)
        stopDisplayTimer()
        if viewers == 0 { manager.stopUpdatingLocation() }
        endLiveActivity()
    }

    // MARK: - Live Activity

    private func beginOrUpdateLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        LiveActivityController.shared.startOrUpdate(
            distance: stats.distance, elevationGain: stats.elevationGain,
            paceSecondsPerKilometer: stats.paceSecondsPerKilometer,
            activeDuration: stats.duration, isRunning: state == .recording)
    }

    private func refreshLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        LiveActivityController.shared.update(
            distance: stats.distance, elevationGain: stats.elevationGain,
            paceSecondsPerKilometer: stats.paceSecondsPerKilometer,
            activeDuration: stats.duration, isRunning: state == .recording)
    }

    private func endLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        LiveActivityController.shared.end()
    }

    // MARK: - Restore

    private func restoreSession() {
        guard let saved = store.loadMeta() else { return }
        meta = saved
        points = store.loadPoints()
        replayStats()
        if saved.isRecording {
            state = .recording
            enableBackgroundUpdates(true)
            requestAuthorizationIfNeeded()
            manager.startUpdatingLocation()
            startDisplayTimer()
        } else {
            state = .paused
        }
        beginOrUpdateLiveActivity()
    }

    /// Recompute distance/elevation from stored points (duration comes from meta).
    private func replayStats() {
        var distance: CLLocationDistance = 0
        var gain: CLLocationDistance = 0
        var previous: CLLocation?
        var reference: Double?
        for point in points {
            let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
            if let previous { distance += location.distance(from: previous) }
            gain += elevationDelta(altitude: point.altitude, reference: &reference)
            previous = location
        }
        lastAccepted = previous
        gainReferenceAltitude = reference
        stats.distance = distance
        stats.elevationGain = gain
        recomputeDuration()
    }

    // MARK: - Helpers

    private func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: authorizationDenied = true
        default: authorizationDenied = false
        }
    }

    private func enableBackgroundUpdates(_ enabled: Bool) {
        // Requires the `location` UIBackgroundMode in Info.plist; setting this
        // true without it crashes, so it's gated on the recording state.
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        // Ticks the clock even when no new fix arrives (e.g. standing still).
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recomputeDuration()
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func recomputeDuration() {
        stats.duration = meta?.activeDuration() ?? 0
    }

    private func persistMeta() {
        if let meta { store.saveMeta(meta) }
    }

    /// Positive elevation change past the deadband, updating the moving reference.
    private func elevationDelta(altitude: Double, reference: inout Double?) -> CLLocationDistance {
        guard let current = reference else { reference = altitude; return 0 }
        let delta = altitude - current
        if delta > elevationDeadband { reference = altitude; return delta }
        if altitude < current { reference = altitude }
        return 0
    }
}

extension TrackRecorder: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            authorizationDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            if viewers > 0 || state == .recording { manager.startUpdatingLocation() }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latest = locations.last
        guard state == .recording else { recomputeDuration(); return }

        for location in locations {
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= horizontalAccuracyLimit else { continue }

            if let previous = lastAccepted {
                stats.distance += location.distance(from: previous)
            }
            stats.elevationGain += elevationDelta(altitude: location.altitude, reference: &gainReferenceAltitude)
            lastAccepted = location

            let point = TrackPoint(location)
            points.append(point)
            store.appendPoint(point)
        }
        recomputeDuration()
        refreshLiveActivity()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures are common outdoors; keep the session going.
    }
}
