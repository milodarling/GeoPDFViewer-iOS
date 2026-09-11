import Foundation
import PDFKit

/// Outcome of loading a PDF and interpreting its geospatial data.
public enum GeoPDFLoadOutcome {
    /// PDF opened and a supported georeferencer was built.
    case georeferenced(document: PDFDocument, georeferencer: Georeferencer, warnings: [String])
    /// PDF opened but its geospatial data isn't supported (still displayable).
    case unsupported(document: PDFDocument, reason: GeoPDFUnsupportedReason)
    /// PDF could not be opened at all.
    case failed(message: String)
}

/// Opens a PDF, extracts its geospatial data, and asks the registry whether it
/// can be georeferenced — the single entry point the UI needs.
public struct GeoPDFLoader {
    public var registry: GeoreferencerRegistry

    public init(registry: GeoreferencerRegistry = .default) {
        self.registry = registry
    }

    public func load(url: URL) -> GeoPDFLoadOutcome {
        guard let document = PDFDocument(url: url) else {
            return .failed(message: "This file could not be opened as a PDF.")
        }
        guard let cgDocument = document.documentRef else {
            return .unsupported(document: document, reason: GeoPDFUnsupportedReason(
                code: .malformed, message: "The PDF's structure could not be read."))
        }

        let measures = GeoPDFParser.parseMeasures(document: cgDocument, pageNumber: 1)
        guard let measure = measures.first else {
            return .unsupported(document: document, reason: GeoPDFUnsupportedReason(
                code: .noGeospatialData,
                message: "This PDF has no geospatial information, so your location can't be shown on it."))
        }

        var warnings: [String] = []
        if measure.totalGeoViewports > 1 {
            warnings.append("This map has \(measure.totalGeoViewports) georeferenced frames; showing your location on the first.")
        }

        switch registry.makeGeoreferencer(from: measure) {
        case .success(let georeferencer):
            return .georeferenced(document: document, georeferencer: georeferencer, warnings: warnings)
        case .rejected(let reason):
            return .unsupported(document: document, reason: reason)
        }
    }
}
