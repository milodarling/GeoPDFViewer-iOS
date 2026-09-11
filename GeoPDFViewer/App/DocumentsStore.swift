import Foundation

/// Access to the app's Documents directory — the folder shown in the Files app
/// (under "On My iPhone ▸ GeoPDFViewer") thanks to `UIFileSharingEnabled` and
/// `LSSupportsOpeningDocumentsInPlace` in Info.plist. Drop GeoPDFs there and
/// they appear in the app's list; files opened via the picker are copied here.
enum DocumentsStore {
    /// The app's Documents directory (created by the system).
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// PDFs currently in Documents, sorted by name (case-insensitive).
    static func pdfURLs() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Copy a file into Documents, returning its new URL. If a file with the
    /// same name exists, a numeric suffix is added ("Map 2.pdf").
    @discardableResult
    static func importFile(from source: URL) throws -> URL {
        let destination = uniqueDestination(for: source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    private static func uniqueDestination(for filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var candidate = documentsURL.appendingPathComponent(filename)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = documentsURL.appendingPathComponent(name)
            index += 1
        }
        return candidate
    }
}
