import SwiftUI

/// Top of each exercise in a live workout: photo, name, target, "Last time", note,
/// and the progressive-overload banner.
struct WorkoutExerciseHeader: View {
    let entry: WorkoutExercise
    let unit: WeightUnit
    let onApply: (OverloadSuggestion) -> Void
    let onDismissSuggestion: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ExerciseThumbnail(imageData: entry.exercise?.imageData, size: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.title3.bold())
                    if let exercise = entry.exercise {
                        Text(exercise.targetSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(lastTimeText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Menu {
                    Button("Remove from Workout", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Exercise options")
            }

            if let note = entry.exercise?.note, !note.isEmpty {
                Label(note, systemImage: "note.text")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let exercise = entry.exercise, !entry.progressionApplied {
                switch ProgressionService.overloadStatus(for: exercise, unit: unit) {
                case .increase(let suggestion):
                    OverloadBanner(
                        suggestion: suggestion,
                        unit: unit,
                        onApply: { onApply(suggestion) },
                        onDismiss: onDismissSuggestion
                    )
                case .keepWeight(let repMax):
                    Label("Keep this weight – aim for \(repMax) reps on every set.", systemImage: "equal.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .noHistory:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 6)
        .buttonStyle(.borderless) // only the buttons themselves are tappable, not the whole row
    }

    /// "Last time: 60 kg × 10, 10, 9"
    private var lastTimeText: String {
        guard let exercise = entry.exercise,
              let last = ProgressionService.lastPerformance(for: exercise),
              !last.sets.isEmpty else {
            return "First time – no history yet"
        }
        return "Last time: " + ProgressionService.summary(of: last.sets, unit: unit)
    }
}
