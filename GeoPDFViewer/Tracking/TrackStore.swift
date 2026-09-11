import Foundation

/// On-disk persistence for the active tracking session. Points are appended as
/// JSON lines, so a crash or forced termination loses at most the last unwritten
/// fix and the session resumes on next launch. Lives in Application Support
/// (not user-visible in Files).
final class TrackStore {
    static let shared = TrackStore()

    private let directory: URL
    private let metaURL: URL
    private let pointsURL: URL
    private let queue = DispatchQueue(label: "com.milodarling.GeoPDFViewer.trackstore")

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("ActiveSession", isDirectory: true)
        metaURL = directory.appendingPathComponent("meta.json")
        pointsURL = directory.appendingPathComponent("points.jsonl")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadMeta() -> TrackSessionMeta? {
        guard let data = try? Data(contentsOf: metaURL) else { return nil }
        return try? decoder.decode(TrackSessionMeta.self, from: data)
    }

    func saveMeta(_ meta: TrackSessionMeta) {
        guard let data = try? encoder.encode(meta) else { return }
        queue.async { try? data.write(to: self.metaURL, options: .atomic) }
    }

    func loadPoints() -> [TrackPoint] {
        guard let data = try? Data(contentsOf: pointsURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            try? decoder.decode(TrackPoint.self, from: Data(line.utf8))
        }
    }

    func appendPoint(_ point: TrackPoint) {
        guard var data = try? encoder.encode(point) else { return }
        data.append(0x0A) // '\n'
        queue.async {
            if let handle = try? FileHandle(forWritingTo: self.pointsURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                // File doesn't exist yet — create it with this first line.
                try? data.write(to: self.pointsURL, options: .atomic)
            }
        }
    }

    /// Delete the whole session (points + meta).
    func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: self.pointsURL)
            try? FileManager.default.removeItem(at: self.metaURL)
        }
    }
}
