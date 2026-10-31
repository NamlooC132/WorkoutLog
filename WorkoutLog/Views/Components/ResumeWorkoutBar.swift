import SwiftUI

/// Banner shown at the top of the app while a workout is minimized.
struct ResumeWorkoutBar: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Workout in progress")
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                    Text(session.routineName)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                Text(session.startedAt, style: .timer)
                    .font(.headline.monospacedDigit())
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(.bar)
        .accessibilityLabel("Resume workout \(session.routineName)")
    }
}
