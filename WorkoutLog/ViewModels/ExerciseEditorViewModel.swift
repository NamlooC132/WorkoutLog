import Foundation
import SwiftData
import Observation

/// Holds an editable draft of an exercise so "Cancel" really cancels.
/// Changes are copied to the database only on `save`.
@MainActor
@Observable
final class ExerciseEditorViewModel {
    static let baseIncrements: [Double] = [0.5, 1, 1.25, 2, 2.5, 5, 10]

    var name: String
    var imageData: Data?
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    var restSeconds: Int
    var weightIncrement: Double
    var note: String

    @ObservationIgnored private let existing: Exercise?

    init(exercise: Exercise?) {
        existing = exercise
        name = exercise?.name ?? ""
        imageData = exercise?.imageData
        targetSets = exercise?.targetSets ?? 3
        repMin = exercise?.repMin ?? 8
        repMax = exercise?.repMax ?? 12
        restSeconds = exercise?.restSeconds ?? AppSettings.defaultRestSeconds
        weightIncrement = exercise?.weightIncrement ?? AppSettings.defaultWeightIncrement
        note = exercise?.note ?? ""
    }

    var isEditing: Bool { existing != nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// How many routines will see an edit (shown as a hint).
    var routineCount: Int { existing?.routineItems.count ?? 0 }

    /// Increment choices, always including the current value.
    var incrementOptions: [Double] {
        Array(Set(Self.baseIncrements + [weightIncrement])).sorted()
    }

    /// Writes the draft to the database and returns the exercise.
    @discardableResult
    func save(in context: ModelContext) -> Exercise {
        let exercise: Exercise
        if let existing {
            exercise = existing
        } else {
            exercise = Exercise(name: "")
            context.insert(exercise)
        }
        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.imageData = imageData
        exercise.targetSets = targetSets
        exercise.repMin = min(repMin, repMax)
        exercise.repMax = max(repMin, repMax)
        exercise.restSeconds = RestTime.clamp(restSeconds)
        exercise.weightIncrement = weightIncrement
        exercise.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        WorkoutService.save(context)
        return exercise
    }
}
