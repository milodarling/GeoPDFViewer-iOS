import Foundation

/// Raw geospatial registration data extracted from a single ISO 32000
/// `/Viewport` + `/Measure` (`/Subtype /GEO`) pair.
///
/// This is a *faithful, unopinionated* view of what the PDF contains. Validation
/// and interpretation happen later in `GeoreferencerBuilder`s, so that new map
/// types can be supported without changing the parser.
public struct MeasureGEO {
    /// Viewport `/BBox` — the rectangle in PDF *page* coordinates (points) that
    /// the georeferenced map occupies. Stored as `[x1, y1, x2, y2]` exactly as
    /// authored; the two pairs are opposite corners.
    public let bbox: [Double]

    /// Page-space registration points as *fractions* of `bbox`, taken pairwise as
    /// `(x, y)` in `[0, 1]`. This is `/LPTS` if present, otherwise `/Bounds`.
    public let pageFractions: [Double]

    /// Geographic registration points, taken pairwise as `(latitude, longitude)`.
    public let gpts: [Double]

    /// Coordinate-system well-known text from `/GCS`, if present.
    public let gcsWKT: String?
    /// `/Type` name of the `/GCS` dictionary (e.g. "PROJCS", "GEOGCS"), if present.
    public let gcsType: String?
    /// `/EPSG` code from `/GCS`, if the producer supplied one directly.
    public let gcsEPSG: Int?

    /// Total number of GEO viewports found on the page (>1 means the map has
    /// multiple registered frames; we currently use only the first).
    public let totalGeoViewports: Int
}
