import Foundation

/// Shared, locale-aware formatting for session stats, used by the live HUD and
/// the saved-session detail view so they always read the same way.
enum StatFormatting {
    static var usesMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func distance(_ meters: Double) -> String { length(meters) }
    static func elevation(_ meters: Double) -> String { length(meters) }

    static func pace(secondsPerKilometer: Double?) -> String {
        guard let secondsPerKm = secondsPerKilometer else { return "—" }
        let secondsPerUnit = usesMetric ? secondsPerKm : secondsPerKm * 1.609344
        let seconds = Int(secondsPerUnit.rounded())
        return String(format: "%d:%02d /%@", seconds / 60, seconds % 60, usesMetric ? "km" : "mi")
    }

    private static func length(_ meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 2
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}
