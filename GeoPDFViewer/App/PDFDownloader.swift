import Foundation

enum PDFDownloadError: LocalizedError {
    case invalidURL
    case unsupportedScheme
    case requestFailed(Int)
    case notAPDF

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The QR code doesn't contain a valid web link."
        case .unsupportedScheme: return "Only http and https links are supported."
        case .requestFailed(let code): return "Download failed (HTTP \(code))."
        case .notAPDF: return "The linked file isn't a PDF."
        }
    }
}

/// Turns a scanned QR string into a PDF in the app's Documents folder.
enum PDFDownloader {
    /// Parse and validate a scanned string as an http(s) URL.
    static func url(from scanned: String) throws -> URL {
        let trimmed = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            throw PDFDownloadError.invalidURL
        }
        guard scheme == "http" || scheme == "https" else {
            throw PDFDownloadError.unsupportedScheme
        }
        return url
    }

    /// Download the PDF at `url` and import it into Documents. Returns the new URL.
    static func downloadAndImport(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw PDFDownloadError.requestFailed(http.statusCode)
        }
        guard isPDF(fileURL: tempURL, response: response) else {
            throw PDFDownloadError.notAPDF
        }

        let name = suggestedFilename(url: url, response: response)
        return try DocumentsStore.importFile(from: tempURL, preferredName: name)
    }

    /// Confirm the payload is really a PDF — trust the `%PDF-` magic bytes over
    /// the server-reported MIME type, which is often wrong or missing.
    private static func isPDF(fileURL: URL, response: URLResponse) -> Bool {
        if let handle = try? FileHandle(forReadingFrom: fileURL) {
            defer { try? handle.close() }
            if let head = try? handle.read(upToCount: 5), Array(head) == Array("%PDF-".utf8) {
                return true
            }
        }
        return (response.mimeType ?? "").lowercased() == "application/pdf"
    }

    private static func suggestedFilename(url: URL, response: URLResponse) -> String {
        var name = response.suggestedFilename ?? url.lastPathComponent
        if name.isEmpty || name == "/" { name = "Downloaded Map.pdf" }
        if !name.lowercased().hasSuffix(".pdf") { name += ".pdf" }
        return name
    }
}
