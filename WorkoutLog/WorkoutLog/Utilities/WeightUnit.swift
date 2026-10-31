import Foundation

/// The unit weights are shown in. Weights are always *stored* in kilograms,
/// so switching units never corrupts history – only the display changes.
enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case kg
    case lbs

    var id: String { rawValue }

    static let kilogramsPerPound = 0.45359237

    var symbol: String {
        switch self {
        case .kg: "kg"
        case .lbs: "lbs"
        }
    }

    var displayName: String {
        switch self {
        case .kg: "Kilograms (kg)"
        case .lbs: "Pounds (lbs)"
        }
    }

    /// Fixed progressive-overload jump: exactly 2.5 kg or 5 lbs.
    var progressionStep: Double {
        switch self {
        case .kg: 2.5
        case .lbs: 5
        }
    }

    /// Converts a stored kilogram value into this unit.
    func fromKg(_ kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lbs: kg / Self.kilogramsPerPound
        }
    }

    /// Converts a value typed in this unit into kilograms for storage.
    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lbs: value * Self.kilogramsPerPound
        }
    }
}

/// Helpers for rest times, which must always be a multiple of 15 seconds.
enum RestTime {
    static let step = 15
    static let range = 15...600

    /// Snaps any value to the nearest 15 s step inside the allowed range.
    static func clamp(_ seconds: Int) -> Int {
        let snapped = Int((Double(seconds) / Double(step)).rounded()) * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}
