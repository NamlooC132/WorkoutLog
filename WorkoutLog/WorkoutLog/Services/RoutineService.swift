import SwiftUI
import SwiftData

/// Create / rename / duplicate / reorder / delete routines and their exercise lists.
@MainActor
enum RoutineService {

    @discardableResult
    static func create(name: String, context: ModelContext) -> Routine {
        let routine = Routine(name: cleaned(name, fallback: "New Routine"), sortIndex: nextSortIndex(context))
        context.insert(routine)
        WorkoutService.save(context)
        return routine
    }

    static func rename(_ routine: Routine, to name: String, context: ModelContext) {
        routine.name = cleaned(name, fallback: routine.name)
        WorkoutService.save(context)
    }

    /// Copies a routine (same library exercises, same order) and places it at the end.
    @discardableResult
    static func duplicate(_ routine: Routine, context: ModelContext) -> Routine {
        let copy = Routine(name: "\(routine.name) Copy", sortIndex: nextSortIndex(context))
        context.insert(copy)
        add(routine.exercises, to: copy, context: context)
        WorkoutService.save(context)
        return copy
    }

    /// Deletes the routine. Library exercises and workout history are kept.
    static func delete(_ routine: Routine, context: ModelContext) {
        context.delete(routine)
        WorkoutService.save(context)
    }

    /// Reorders the routines list (drag & drop).
    static func move(_ routines: [Routine], from source: IndexSet, to destination: Int, context: ModelContext) {
        var reordered = routines
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, routine) in reordered.enumerated() {
            routine.sortIndex = index
        }
        WorkoutService.save(context)
    }

    /// Appends library exercises to the end of a routine.
    static func add(_ exercises: [Exercise], to routine: Routine, context: ModelContext) {
        var next = (routine.items.map(\.sortIndex).max() ?? -1) + 1
        for exercise in exercises {
            let item = RoutineExercise(sortIndex: next)
            context.insert(item)
            item.exercise = exercise
            routine.items.append(item)
            next += 1
        }
        WorkoutService.save(context)
    }

    /// Removes exercises from this routine only (they stay in the library).
    static func removeItems(at offsets: IndexSet, from routine: Routine, context: ModelContext) {
        let ordered = routine.orderedItems
        let doomed = offsets.map { ordered[$0] }
        for item in doomed {
            routine.items.removeAll { $0.id == item.id }
            context.delete(item)
        }
        WorkoutService.save(context)
    }

    /// Reorders exercises within a routine (drag to reorder).
    static func moveItems(in routine: Routine, from source: IndexSet, to destination: Int, context: ModelContext) {
        var ordered = routine.orderedItems
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.sortIndex = index
        }
        WorkoutService.save(context)
    }

    // MARK: - Helpers

    static func nextSortIndex(_ context: ModelContext) -> Int {
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        return (routines.map(\.sortIndex).max() ?? -1) + 1
    }

    private static func cleaned(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
