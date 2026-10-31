import Foundation
import SwiftData

/// One workout, either in progress (`isFinished == false`) or saved to history.
///
/// The in-progress workout is a normal database record that is saved on every
/// change, which is what lets the app restore it after being closed or killed.
@Model
final class WorkoutSession {
    var id: UUID
    /// Copy of the routine name at the time (so renaming a routine doesn't rewrite history).
    var routineName: String
    var routineID: UUID?
    var startedAt: Date
    var endedAt: Date?
    var isFinished: Bool
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var entries: [WorkoutExercise] = []

    init(
        id: UUID = UUID(),
        routineName: String,
        routineID: UUID? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        isFinished: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.routineName = routineName
        self.routineID = routineID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isFinished = isFinished
        self.notes = notes
    }

    var orderedEntries: [WorkoutExercise] {
        entries.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Workout length. Uses "now" while the workout is still running.
    var duration: TimeInterval {
        max(0, (endedAt ?? .now).timeIntervalSince(startedAt))
    }

    var completedSetCount: Int {
        entries.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var totalSetCount: Int {
        entries.reduce(0) { $0 + $1.sets.count }
    }

    /// Sum of weight × reps over completed sets, in kilograms.
    var totalVolumeKg: Double {
        entries.reduce(0) { total, entry in
            total + entry.sets.filter(\.isCompleted).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        }
    }
}

/// One exercise inside a workout.
@Model
final class WorkoutExercise {
    var id: UUID
    var sortIndex: Int
    /// Name snapshot, used if the library exercise is later deleted.
    var exerciseName: String
    /// True once the user tapped "Apply" (or dismissed) the progressive-overload banner.
    var progressionApplied: Bool

    var exercise: Exercise?
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.entry)
    var sets: [WorkoutSet] = []

    init(id: UUID = UUID(), sortIndex: Int, exerciseName: String, progressionApplied: Bool = false) {
        self.id = id
        self.sortIndex = sortIndex
        self.exerciseName = exerciseName
        self.progressionApplied = progressionApplied
    }

    /// Live name from the library if it still exists, otherwise the snapshot.
    var displayName: String {
        exercise?.name ?? exerciseName
    }

    var orderedSets: [WorkoutSet] {
        sets.sorted { $0.position < $1.position }
    }

    var completedSets: [WorkoutSet] {
        orderedSets.filter(\.isCompleted)
    }
}

/// A single set: weight × reps.
@Model
final class WorkoutSet {
    var id: UUID
    var position: Int
    /// Always stored in kilograms; converted for display when the unit is lbs.
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?

    var entry: WorkoutExercise?

    init(
        id: UUID = UUID(),
        position: Int,
        weightKg: Double,
        reps: Int,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.position = position
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
