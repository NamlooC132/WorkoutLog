import Foundation
import SwiftData

/// Creates, edits and finishes workouts. Every change is saved straight away,
/// so an in-progress workout survives the app being closed or killed.
@MainActor
enum WorkoutService {

    /// Starts a live workout from a routine, prefilling each set from last time.
    @discardableResult
    static func start(routine: Routine, context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(routineName: routine.name, routineID: routine.id)
        context.insert(session)
        for (index, exercise) in routine.exercises.enumerated() {
            addEntry(for: exercise, sortIndex: index, to: session, context: context)
        }
        save(context)
        return session
    }

    /// Adds an exercise to a workout with `targetSets` rows.
    /// Each row is prefilled with the matching set from the last session
    /// (or the last logged set if last time had fewer sets).
    static func addEntry(for exercise: Exercise, sortIndex: Int, to session: WorkoutSession, context: ModelContext) {
        // Read history *before* creating the new entry.
        let lastSets = ProgressionService.lastPerformance(for: exercise)?.sets ?? []

        let entry = WorkoutExercise(sortIndex: sortIndex, exerciseName: exercise.name)
        context.insert(entry)
        entry.exercise = exercise
        session.entries.append(entry)

        for i in 0..<max(1, exercise.targetSets) {
            let source = i < lastSets.count ? lastSets[i] : lastSets.last
            let set = WorkoutSet(
                position: i,
                weightKg: source?.weightKg ?? 0,
                reps: source?.reps ?? exercise.repMin
            )
            context.insert(set)
            entry.sets.append(set)
        }
    }

    /// Adds library exercises to the end of a workout.
    static func addExercises(_ exercises: [Exercise], to session: WorkoutSession, context: ModelContext) {
        var next = (session.entries.map(\.sortIndex).max() ?? -1) + 1
        for exercise in exercises {
            addEntry(for: exercise, sortIndex: next, to: session, context: context)
            next += 1
        }
        save(context)
    }

    /// Appends a set copying the previous set's weight and reps.
    @discardableResult
    static func addSet(to entry: WorkoutExercise, completed: Bool = false, context: ModelContext) -> WorkoutSet {
        let existing = entry.orderedSets
        let template = existing.last
        let set = WorkoutSet(
            position: (existing.map(\.position).max() ?? -1) + 1,
            weightKg: template?.weightKg ?? 0,
            reps: template?.reps ?? (entry.exercise?.repMin ?? 8),
            isCompleted: completed,
            completedAt: completed ? .now : nil
        )
        context.insert(set)
        entry.sets.append(set)
        save(context)
        return set
    }

    static func removeSet(_ set: WorkoutSet, from entry: WorkoutExercise, context: ModelContext) {
        entry.sets.removeAll { $0.id == set.id }
        context.delete(set)
        save(context)
    }

    static func removeEntry(_ entry: WorkoutExercise, from session: WorkoutSession, context: ModelContext) {
        session.entries.removeAll { $0.id == entry.id }
        context.delete(entry)
        save(context)
    }

    /// Saves the workout to history.
    /// - Parameter discardUnchecked: `true` drops sets that were never ticked;
    ///   `false` marks them as completed (sets with 0 reps are always dropped).
    static func finish(_ session: WorkoutSession, discardUnchecked: Bool, context: ModelContext) {
        for entry in session.entries {
            for set in entry.sets where !set.isCompleted {
                if discardUnchecked || set.reps <= 0 {
                    entry.sets.removeAll { $0.id == set.id }
                    context.delete(set)
                } else {
                    set.isCompleted = true
                    set.completedAt = .now
                }
            }
        }
        // Exercises with nothing logged are not worth keeping in history.
        for entry in session.entries where entry.sets.isEmpty {
            session.entries.removeAll { $0.id == entry.id }
            context.delete(entry)
        }
        session.endedAt = .now
        session.isFinished = true
        save(context)
    }

    /// Deletes a workout (in progress or from history).
    static func delete(_ session: WorkoutSession, context: ModelContext) {
        context.delete(session)
        save(context)
    }

    static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            // SwiftData also autosaves; log rather than crash.
            print("⚠️ Save failed: \(error)")
        }
    }
}
