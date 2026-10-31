import Foundation
import SwiftData

/// A saved workout template – shown as a "folder" on the Routines screen (e.g. "Push Day").
///
/// A routine does not own its exercises. It holds an ordered list of `RoutineExercise`
/// entries that point at exercises in the shared library, so the same exercise
/// (and its history) can appear in many routines.
@Model
final class Routine {
    var id: UUID
    var name: String
    /// Position on the Routines screen (0 = top).
    var sortIndex: Int
    var createdAt: Date

    /// Deleting a routine deletes these join entries – never the library exercises.
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var items: [RoutineExercise] = []

    init(id: UUID = UUID(), name: String, sortIndex: Int, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    /// Entries in the order the user arranged them.
    /// (SwiftData relationship arrays are unordered, so we sort by `sortIndex`.)
    var orderedItems: [RoutineExercise] {
        items.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The library exercises in routine order.
    var exercises: [Exercise] {
        orderedItems.compactMap(\.exercise)
    }
}

/// Join model: "exercise X is at position N in routine Y".
@Model
final class RoutineExercise {
    var id: UUID
    var sortIndex: Int
    var routine: Routine?
    var exercise: Exercise?

    init(id: UUID = UUID(), sortIndex: Int) {
        self.id = id
        self.sortIndex = sortIndex
    }
}
