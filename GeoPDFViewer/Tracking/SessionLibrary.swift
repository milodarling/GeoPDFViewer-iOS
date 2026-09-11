import Foundation

/// Stores completed sessions under Application Support/Sessions/<id>/, each with
/// a small `summary.json` (for the list) and a `points.jsonl` (the full track).
final class SessionLibrary {
    static let shared = SessionLibrary()

    private let root: URL
    private let queue = DispatchQueue(label: "com.milodarling.GeoPDFViewer.sessionlibrary")

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
        root = base.appendingPathComponent("Sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// A default title from the session's start time, e.g. "Sep 11, 2026 at 2:30 PM".
    static func defaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// All saved sessions, most recent first.
    func summaries() -> [SessionSummary] {
        let directories = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil)) ?? []
        return directories
            .compactMap { dir -> SessionSummary? in
                guard let data = try? Data(contentsOf: dir.appendingPathComponent("summary.json")) else { return nil }
                return try? decoder.decode(SessionSummary.self, from: data)
            }
            .sorted { $0.startDate > $1.startDate }
    }

    func points(for id: UUID) -> [TrackPoint] {
        let url = root.appendingPathComponent(id.uuidString).appendingPathComponent("points.jsonl")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { try? decoder.decode(TrackPoint.self, from: Data($0.utf8)) }
    }

    func save(summary: SessionSummary, points: [TrackPoint]) {
        queue.async {
            let dir = self.root.appendingPathComponent(summary.id.uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? self.encoder.encode(summary) {
                try? data.write(to: dir.appendingPathComponent("summary.json"), options: .atomic)
            }
            let lines = points.compactMap { point -> String? in
                guard let data = try? self.encoder.encode(point) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            try? lines.joined(separator: "\n").data(using: .utf8)?
                .write(to: dir.appendingPathComponent("points.jsonl"), options: .atomic)
        }
    }

    func delete(_ id: UUID) {
        queue.async {
            try? FileManager.default.removeItem(at: self.root.appendingPathComponent(id.uuidString))
        }
    }
}
