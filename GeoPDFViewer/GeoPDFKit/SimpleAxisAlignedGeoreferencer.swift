import CoreGraphics
import CoreLocation

/// Handles the simplest (and common consumer-map) case: the georeferenced area
/// is a rectangle aligned to lines of latitude and longitude, north-up, with
/// GPTS already expressed as WGS84 lat/lon. Placement is a plain linear scale —
/// no projection or bilinear math required.
///
/// This type is only ever constructed by `SimpleAxisAlignedGeoreferencerBuilder`,
/// which validates that these assumptions actually hold.
public struct SimpleAxisAlignedGeoreferencer: Georeferencer {
    /// longitude -> x as a fraction of the BBox.
    let lonToFx: LinearFit
    /// latitude -> y as a fraction of the BBox.
    let latToFy: LinearFit
    /// `[x1, y1, x2, y2]`; fraction (0,0) maps to (x1,y1) and (1,1) to (x2,y2).
    let bbox: [Double]

    public let geographicBounds: GeographicBounds

    /// Tolerance (in fraction units) so a fix exactly on the neatline counts as inside.
    private let edgeTolerance = 0.0005

    private func fraction(for c: CLLocationCoordinate2D) -> CGPoint {
        CGPoint(x: lonToFx(c.longitude), y: latToFy(c.latitude))
    }

    public func pagePoint(for coordinate: CLLocationCoordinate2D) -> CGPoint? {
        let f = fraction(for: coordinate)
        let x = bbox[0] + Double(f.x) * (bbox[2] - bbox[0])
        let y = bbox[1] + Double(f.y) * (bbox[3] - bbox[1])
        return CGPoint(x: x, y: y)
    }

    public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let f = fraction(for: coordinate)
        let range = -edgeTolerance ... (1 + edgeTolerance)
        return range.contains(Double(f.x)) && range.contains(Double(f.y))
    }
}

/// Builds a `SimpleAxisAlignedGeoreferencer`, but only after proving the map
/// meets every assumption. Any failed check returns a specific, user-facing
/// rejection instead — this is where "is this map supported?" is decided.
public struct SimpleAxisAlignedGeoreferencerBuilder: GeoreferencerBuilder {
    public let name = "SimpleAxisAligned"

    /// Degrees. ~1e-4° ≈ 11 m: tight enough to reject projected quads whose
    /// lat/lon corners form a trapezoid, loose enough for float round-trip noise.
    private let rectangleTolerance = 1e-4
    /// Fraction units. Residual of the linear fit; catches rotation/skew.
    private let fitResidualTolerance = 1e-3

    public init() {}

    public func build(from m: MeasureGEO) -> GeoreferencerBuildResult {
        func reject(_ code: GeoPDFUnsupportedReason.Code, _ message: String) -> GeoreferencerBuildResult {
            .rejected(GeoPDFUnsupportedReason(code: code, message: message))
        }

        // 1. Basic shape.
        guard m.bbox.count == 4 else {
            return reject(.malformed, "This map is missing a valid page rectangle (BBox).")
        }
        guard m.gpts.count == 8, m.pageFractions.count == 8 else {
            let corners = m.gpts.count / 2
            return reject(.nonStandardRegistration,
                "This map uses \(corners) registration points; only simple 4-corner maps are supported.")
        }

        let fractionPoints = pairs(m.pageFractions)          // (x, y) in [0,1]
        let geoPoints = pairs(m.gpts)                        // (lat, lon)

        // 2. Registration must be the four unit corners of the BBox — i.e. the
        //    whole frame is the map, not a clipped sub-polygon (neatline).
        let unitCorners: [(Double, Double)] = [(0, 0), (0, 1), (1, 0), (1, 1)]
        let coversUnitSquare = fractionPoints.count == 4 && unitCorners.allSatisfy { corner in
            fractionPoints.contains { abs($0.0 - corner.0) < 1e-6 && abs($0.1 - corner.1) < 1e-6 }
        }
        guard coversUnitSquare else {
            return reject(.nonStandardRegistration,
                "This map registers a custom region rather than its full frame, which isn't supported yet.")
        }

        // 3. GPTS must look like lat/lon, not projected units (e.g. UTM meters).
        let lats = geoPoints.map { $0.0 }
        let lons = geoPoints.map { $0.1 }
        let inGeographicRange = lats.allSatisfy { (-90.0...90.0).contains($0) }
            && lons.allSatisfy { (-180.0...180.0).contains($0) }
        guard inGeographicRange else {
            return reject(.projectedCoordinates,
                "This map stores positions in a projected coordinate system, which isn't supported yet.")
        }

        // 4. The four geographic corners must form an axis-aligned rectangle:
        //    exactly two distinct latitudes and two distinct longitudes. A
        //    rotated or projected quad fails here.
        let latClusters = distinctClusters(lats, tolerance: rectangleTolerance)
        let lonClusters = distinctClusters(lons, tolerance: rectangleTolerance)
        guard latClusters.count == 2, lonClusters.count == 2 else {
            return reject(.rotatedOrSkewed,
                "This map is rotated or projected (its corners don't line up with latitude/longitude), which isn't supported yet.")
        }

        // 5. Fit lon->x and lat->y from the corner correspondences. A clean fit
        //    confirms x depends only on longitude and y only on latitude (i.e.
        //    north-up); a poor fit means the axes are swapped or skewed.
        let fx = fractionPoints.map { Double($0.0) }
        let fy = fractionPoints.map { Double($0.1) }
        guard let lonToFx = linearFit(xs: lons, ys: fx),
              let latToFy = linearFit(xs: lats, ys: fy),
              lonToFx.maxResidual < fitResidualTolerance,
              latToFy.maxResidual < fitResidualTolerance else {
            return reject(.rotatedOrSkewed,
                "This map's axes don't align with latitude/longitude, which isn't supported yet.")
        }

        let bounds = GeographicBounds(
            minLatitude: latClusters.first!, maxLatitude: latClusters.last!,
            minLongitude: lonClusters.first!, maxLongitude: lonClusters.last!)

        return .success(SimpleAxisAlignedGeoreferencer(
            lonToFx: lonToFx, latToFy: latToFy, bbox: m.bbox, geographicBounds: bounds))
    }

    private func pairs(_ flat: [Double]) -> [(Double, Double)] {
        stride(from: 0, to: flat.count - 1, by: 2).map { (flat[$0], flat[$0 + 1]) }
    }
}
