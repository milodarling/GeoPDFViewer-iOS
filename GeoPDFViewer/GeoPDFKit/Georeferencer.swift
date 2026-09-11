import CoreGraphics
import CoreLocation

/// A geographic bounding box in WGS84 degrees.
public struct GeographicBounds {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2,
                               longitude: (minLongitude + maxLongitude) / 2)
    }
}

/// Maps WGS84 coordinates onto a PDF page. One concrete implementation exists
/// today (`SimpleAxisAlignedGeoreferencer`); add more to support richer maps.
public protocol Georeferencer {
    /// The geographic extent covered by the map.
    var geographicBounds: GeographicBounds { get }

    /// Convert a WGS84 coordinate to a point in PDF *page* space (points).
    /// Returns nil only if the coordinate cannot be represented at all.
    func pagePoint(for coordinate: CLLocationCoordinate2D) -> CGPoint?

    /// Whether `coordinate` falls within the georeferenced map area.
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool
}

/// Why a PDF's geospatial data can't be handled by the currently-installed
/// georeferencers. `message` is safe to show to a user.
public struct GeoPDFUnsupportedReason: Error {
    public enum Code {
        case noGeospatialData
        case malformed
        case projectedCoordinates
        case nonStandardRegistration
        case rotatedOrSkewed
        case multipleFrames
    }
    public let code: Code
    public let message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }
}

/// Result of a single builder attempting to interpret a `MeasureGEO`.
public enum GeoreferencerBuildResult {
    case success(Georeferencer)
    /// This builder can't handle the map; the reason explains why.
    case rejected(GeoPDFUnsupportedReason)
}

/// A strategy that knows how to build a `Georeferencer` for one class of map.
///
/// To support a new map type (e.g. projected UTM quads), implement this protocol
/// and add an instance to `GeoreferencerRegistry.default`. Nothing else — parser,
/// loader, or UI — needs to change.
public protocol GeoreferencerBuilder {
    /// Human-readable name, for diagnostics/logging.
    var name: String { get }
    func build(from measure: MeasureGEO) -> GeoreferencerBuildResult
}

/// Tries each builder in order and returns the first success. If all reject,
/// returns the most specific rejection (the last one attempted).
public struct GeoreferencerRegistry {
    public let builders: [GeoreferencerBuilder]

    public init(builders: [GeoreferencerBuilder]) {
        self.builders = builders
    }

    /// The builders shipped today. Add new `GeoreferencerBuilder`s here — most
    /// specific first — to grow support without touching anything else.
    public static let `default` = GeoreferencerRegistry(builders: [
        SimpleAxisAlignedGeoreferencerBuilder()
        // Future work — see README "Extending support":
        // ProjectedQuadGeoreferencerBuilder(),   // UTM / State Plane USGS US Topo quads
        // BilinearGeoreferencerBuilder(),        // general non-affine 4-corner maps
    ])

    public func makeGeoreferencer(from measure: MeasureGEO) -> GeoreferencerBuildResult {
        var lastRejection: GeoPDFUnsupportedReason?
        for builder in builders {
            switch builder.build(from: measure) {
            case .success(let georeferencer):
                return .success(georeferencer)
            case .rejected(let reason):
                lastRejection = reason
            }
        }
        return .rejected(lastRejection ?? GeoPDFUnsupportedReason(
            code: .malformed,
            message: "This map's geospatial data could not be interpreted."))
    }
}
