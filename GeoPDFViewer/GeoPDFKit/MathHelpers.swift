import Foundation

/// A 1-D affine map `y = slope * x + intercept`, plus the largest residual seen
/// across the points it was fit from (0 for a perfect fit).
public struct LinearFit {
    public let slope: Double
    public let intercept: Double
    public let maxResidual: Double
    public func callAsFunction(_ x: Double) -> Double { slope * x + intercept }
}

/// Least-squares fit of a line to paired samples. Returns nil if the inputs are
/// degenerate (fewer than 2 points, or all `xs` equal).
public func linearFit(xs: [Double], ys: [Double]) -> LinearFit? {
    guard xs.count == ys.count, xs.count >= 2 else { return nil }
    let n = Double(xs.count)
    let sx = xs.reduce(0, +)
    let sy = ys.reduce(0, +)
    let sxx = xs.reduce(0) { $0 + $1 * $1 }
    let sxy = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
    let denom = n * sxx - sx * sx
    guard abs(denom) > 1e-12 else { return nil }
    let slope = (n * sxy - sx * sy) / denom
    let intercept = (sy - slope * sx) / n
    let maxResidual = zip(xs, ys).reduce(0.0) { max($0, abs($1.1 - (slope * $1.0 + intercept))) }
    return LinearFit(slope: slope, intercept: intercept, maxResidual: maxResidual)
}

/// Returns the distinct clusters among `values`, treating values within
/// `tolerance` of each other as the same cluster. Used to detect whether a set
/// of geographic corners forms an axis-aligned rectangle.
public func distinctClusters(_ values: [Double], tolerance: Double) -> [Double] {
    var clusters: [Double] = []
    for v in values.sorted() {
        if let last = clusters.last, abs(v - last) <= tolerance { continue }
        clusters.append(v)
    }
    return clusters
}
