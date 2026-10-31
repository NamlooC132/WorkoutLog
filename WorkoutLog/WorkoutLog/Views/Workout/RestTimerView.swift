import SwiftUI

/// Large rest countdown with −15s / +15s / Skip.
struct RestTimerView: View {
    @Environment(RestTimerService.self) private var timer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = timer.remaining(at: context.date)
            let progress = timer.totalSeconds > 0 ? remaining / Double(timer.totalSeconds) : 0

            VStack(spacing: 10) {
                HStack {
                    Label("Rest", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(timer.exerciseName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)

                Text(Fmt.clock(remaining))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel("Rest remaining \(Fmt.clock(remaining))")

                ProgressView(value: min(max(progress, 0), 1))
                    .tint(Color.accentColor)

                HStack(spacing: 10) {
                    controlButton("−15s") { timer.adjust(by: -RestTime.step) }
                    controlButton("+15s") { timer.adjust(by: RestTime.step) }
                    controlButton("Skip", prominent: true) { timer.skip() }
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }

    @ViewBuilder
    private func controlButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        let label = Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
        }
    }
}
