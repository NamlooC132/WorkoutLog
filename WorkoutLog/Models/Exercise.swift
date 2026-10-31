import Foundation
import SwiftData

/// An exercise in the shared library (e.g. "Bench Press").
///
/// Targets (sets, rep range, rest, increment, note) live here, so editing an exercise
/// updates it in every routine that uses it. All logged history for the exercise is
/// linked through `workoutEntries`, which is why history is shared across routines.
@Model
final class Exercise {
    var id: UUID
    var name: String

    /// Small JPEG thumbnail (already downscaled). Stored outside the main database file.
    @Attribute(.externalStorage)
    var imageData: Data?

    var targetSets: Int
    var repMin: Int
    var repMax: Int
    /// Rest between sets, always a multiple of 15 seconds.
    var restSeconds: Int
    /// Step used by the −/+ buttons next to the weight field, in the user's display unit.
    var weightIncrement: Double
    var note: String
    var createdAt: Date

    /// Removing an exercise from the library also removes it from every routine.
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.exercise)
    var routineItems: [RoutineExercise] = []

    /// Logged history. On delete the link is cleared, but past workouts keep
    /// their sets and a snapshot of the exercise name.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutEntries: [WorkoutExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        imageData: Data? = nil,
        targetSets: Int = 3,
        repMin: Int = 8,
        repMax: Int = 12,
        restSeconds: Int = 90,
        weightIncrement: Double = 2.5,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.targetSets = targetSets
        self.repMin = repMin
        self.repMax = repMax
        self.restSeconds = restSeconds
        self.weightIncrement = weightIncrement
        self.note = note
        self.createdAt = createdAt
    }

    /// Short description such as "3 × 8–12 · Rest 1:30".
    var targetSummary: String {
        "\(targetSets) × \(repMin)–\(repMax) · Rest \(Fmt.rest(restSeconds))"
    }
}
