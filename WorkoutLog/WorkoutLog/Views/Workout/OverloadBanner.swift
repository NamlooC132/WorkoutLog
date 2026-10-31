import SwiftUI

/// Highlighted "add weight" banner with a one-tap Apply.
struct OverloadBanner: View {
    let suggestion: OverloadSuggestion
    let unit: WeightUnit
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                Text("You hit \(suggestion.repMax) reps on every set last time — add \(Fmt.number(unit.progressionStep)) \(unit.symbol)!")
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityLabel("Dismiss suggestion")
            }

            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Suggested")
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                    Text(Fmt.weight(suggestion.suggestedWeightKg, unit: unit))
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                Button(action: onApply) {
                    Text("Apply")
                        .font(.headline)
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Apply \(Fmt.weight(suggestion.suggestedWeightKg, unit: unit)) to all sets")
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
