import Foundation

/// How generous the break ratio is. Three named levels rather than a numeric slider: on a
/// bad day you want to pick "more recovery", not do arithmetic.
public enum BreakGenerosity: String, CaseIterable, Codable, Sendable {
    case low
    case standard
    case high

    /// Fraction of worked time banked as break.
    public var ratio: Double {
        switch self {
        case .low:      return 0.12
        case .standard: return 0.15
        case .high:     return 0.25
        }
    }

    public var title: String {
        switch self {
        case .low:      return "Low"
        case .standard: return "Standard"
        case .high:     return "High"
        }
    }

    /// Concrete, not abstract: what an hour of work buys.
    public var detail: String {
        let perHour = BreakMath.humane(3600 * ratio)
        return "\(Int(ratio * 100))% · \(perHour) per hour"
    }
}
