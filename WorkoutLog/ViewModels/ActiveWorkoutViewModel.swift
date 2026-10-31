import Foundation
import SwiftData
import Observation

/// Drives the live workout screen. All mutations go through `WorkoutService`,
/// which saves immediately so nothing is lost if the app is closed.
@MainActor
@Observable
final class ActiveWorkoutViewModel {
    let session: WorkoutSession
    @ObservationIgnored private let context: ModelContext

    init(session: WorkoutSession, context: ModelContext) {
        self.session = session
        self.context = context
    }

    var entries: [WorkoutExercise] { session.orderedEntries }
    var completedSetCount: Int { session.completedSetCount }
    var totalSetCount: Int { session.totalSetCount }
    var uncheckedSetCount: Int { totalSetCount - completedSetCount }

    /// Ticks or unticks a set. Ticking starts the rest timer with that exercise's rest time.
    func toggleCompletion(of set: WorkoutSet, in entry: WorkoutExercise, timer: RestTimerService) {
        if set.isCompleted {
            set.isCompleted = false
            set.completedAt = nil
            Haptics.tap()
        } else {
            guard set.reps > 0 else {
                Haptics.warning() // need at least 1 rep to complete a set
                return
            }
            set.isCompleted = true
            set.completedAt = .now
            Haptics.success()
            let rest = entry.exercise?.restSeconds ?? AppSettings.defaultRestSeconds
            timer.start(seconds: rest, exerciseName: entry.displayName)
        }
        save()
    }

    func addSet(to entry: WorkoutExercise) {
        WorkoutService.addSet(to: entry, context: context)
        Haptics.tap()
    }

    func removeSet(_ set: WorkoutSet, from entry: WorkoutExercise) {
        WorkoutService.removeSet(set, from: entry, context: context)
    }

    func removeLastSet(from entry: WorkoutExercise) {
        guard let last = entry.orderedSets.last else { return }
        removeSet(last, from: entry)
    }

    /// One-tap "Apply": puts the suggested weight into every set not yet done.
    func applySuggestion(_ suggestion: OverloadSuggestion, to entry: WorkoutExercise) {
        for set in entry.sets where !set.isCompleted {
            set.weightKg = suggestion.suggestedWeightKg
        }
        entry.progressionApplied = true
        Haptics.success()
        save()
    }

    func dismissSuggestion(for entry: WorkoutExercise) {
        entry.progressionApplied = true
        save()
    }

    func addExercises(_ exercises: [Exercise]) {
        WorkoutService.addExercises(exercises, to: session, context: context)
    }

    func removeEntry(_ entry: WorkoutExercise) {
        WorkoutService.removeEntry(entry, from: session, context: context)
    }

    func finish(discardUnchecked: Bool) {
        WorkoutService.finish(session, discardUnchecked: discardUnchecked, context: context)
    }

    func discard() {
        WorkoutService.delete(session, context: context)
    }

    func save() {
        WorkoutService.save(context)
    }
}
