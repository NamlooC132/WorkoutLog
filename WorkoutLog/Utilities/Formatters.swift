import Foundation

/// All number/time formatting in one place so the whole app looks consistent.
enum Fmt {

    /// "62.5", "60", "137.25" – up to 2 decimals, no grouping (safe for input fields).
    private static let plainNumber: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = false
        return f
    }()

    /// "4,250" – whole numbers with grouping, for big totals like volume.
    private static let groupedNumber: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func number(_ value: Double) -> String {
        plainNumber.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Parses user input, accepting both "." and "," as the decimal separator.
    static func parseNumber(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// Stored kilograms → "62.5 kg" / "137.5 lbs".
    static func weight(_ kg: Double, unit: WeightUnit) -> String {
        "\(number(unit.fromKg(kg))) \(unit.symbol)"
    }

    /// Volume in the display unit, e.g. "4,250 kg".
    static func volume(_ kg: Double, unit: WeightUnit) -> String {
        let value = groupedNumber.string(from: NSNumber(value: unit.fromKg(kg))) ?? "0"
        return "\(value) \(unit.symbol)"
    }

    /// 90 → "1:30"
    static func rest(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// Countdown display; rounds up so "0:00" only shows when time is really up.
    static func clock(_ interval: TimeInterval) -> String {
        rest(Int(interval.rounded(.up)))
    }

    /// 3_900 s → "1 h 05 min", 2_820 s → "47 min"
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h " + String(format: "%02d", minutes % 60) + " min"
    }

    /// File-name friendly date: "2026-10-31".
    static func fileDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
