import CoreGraphics
import Foundation

/// Extracts ISO 32000 geospatial (`/Measure` `/Subtype /GEO`) registration data
/// from a PDF using CoreGraphics' low-level object model, which transparently
/// resolves indirect references and object streams.
public enum GeoPDFParser {

    /// Parse all GEO viewports on the given 1-based page of a `CGPDFDocument`.
    public static func parseMeasures(document: CGPDFDocument, pageNumber: Int = 1) -> [MeasureGEO] {
        guard let page = document.page(at: pageNumber),
              let pageDict = page.dictionary else { return [] }

        var vpArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(pageDict, "VP", &vpArray),
              let viewports = vpArray else { return [] }

        // First pass: collect every viewport whose Measure is a GEO measure.
        var geoViewports: [(bbox: [Double], measure: CGPDFDictionaryRef)] = []
        for i in 0..<CGPDFArrayGetCount(viewports) {
            var vpDict: CGPDFDictionaryRef?
            guard CGPDFArrayGetDictionary(viewports, i, &vpDict), let vp = vpDict else { continue }
            var measureDict: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(vp, "Measure", &measureDict), let measure = measureDict else { continue }
            guard name(measure, "Subtype") == "GEO" else { continue }
            geoViewports.append((numberArray(vp, "BBox") ?? [], measure))
        }

        let total = geoViewports.count
        return geoViewports.map { entry -> MeasureGEO in
            let measure = entry.measure
            let gpts = numberArray(measure, "GPTS") ?? []
            let lpts = numberArray(measure, "LPTS")
            let bounds = numberArray(measure, "Bounds") ?? []

            var wkt: String?
            var gcsType: String?
            var epsg: Int?
            var gcsDict: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(measure, "GCS", &gcsDict), let gcs = gcsDict {
                wkt = string(gcs, "WKT")
                gcsType = name(gcs, "Type")
                var value: CGPDFInteger = 0
                if CGPDFDictionaryGetInteger(gcs, "EPSG", &value) { epsg = Int(value) }
            }

            return MeasureGEO(
                bbox: entry.bbox,
                pageFractions: lpts ?? bounds,
                gpts: gpts,
                gcsWKT: wkt,
                gcsType: gcsType,
                gcsEPSG: epsg,
                totalGeoViewports: total)
        }
    }

    // MARK: - CGPDF helpers

    private static func numberArray(_ dict: CGPDFDictionaryRef, _ key: String) -> [Double]? {
        var arrayRef: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, key, &arrayRef), let array = arrayRef else { return nil }
        var out: [Double] = []
        for i in 0..<CGPDFArrayGetCount(array) {
            var real: CGPDFReal = 0
            if CGPDFArrayGetNumber(array, i, &real) { out.append(Double(real)); continue }
            var integer: CGPDFInteger = 0
            if CGPDFArrayGetInteger(array, i, &integer) { out.append(Double(integer)) }
        }
        return out
    }

    private static func name(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var cName: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dict, key, &cName), let c = cName else { return nil }
        return String(cString: c)
    }

    private static func string(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var strRef: CGPDFStringRef?
        guard CGPDFDictionaryGetString(dict, key, &strRef), let s = strRef,
              let cf = CGPDFStringCopyTextString(s) else { return nil }
        return cf as String
    }
}
