import SwiftUI

/// One set: [#] [− weight +] [reps] [✓]. Large targets for sweaty hands.
struct SetRowView: View {
    @Bindable var set: WorkoutSet
    let number: Int
    let unit: WeightUnit
    /// −/+ step in the display unit.
    let increment: Double
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            HStack(spacing: 4) {
                stepButton(systemImage: "minus") { adjustWeight(by: -increment) }
                NumberInputField(value: SetBindings.weight(set, unit: unit), allowsDecimal: true, placeholder: "0")
                stepButton(systemImage: "plus") { adjustWeight(by: increment) }
            }
            .frame(maxWidth: .infinity)

            NumberInputField(value: SetBindings.reps(set), allowsDecimal: false, placeholder: "0")
                .frame(width: 64)

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(set.isCompleted ? "Mark set \(number) not done" : "Complete set \(number)")
        }
        .padding(.vertical, 2)
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .frame(width: 34, height: 48)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.borderless)
    }

    private func adjustWeight(by delta: Double) {
        let current = unit.fromKg(set.weightKg)
        let next = max(0, ((current + delta) * 100).rounded() / 100)
        set.weightKg = unit.toKg(next)
    }
}

/// Bindings that convert between stored values and what the user types.
enum SetBindings {
    /// Weight in the display unit (stored as kg).
    static func weight(_ set: WorkoutSet, unit: WeightUnit) -> Binding<Double> {
        Binding(
            get: { unit.fromKg(set.weightKg) },
            set: { set.weightKg = unit.toKg(max(0, $0)) }
        )
    }

    /// Reps as a Double for `NumberInputField`.
    static func reps(_ set: WorkoutSet) -> Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = max(0, Int($0.rounded())) }
        )
    }
}
