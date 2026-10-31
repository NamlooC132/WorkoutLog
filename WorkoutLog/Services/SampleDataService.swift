import Foundation
import SwiftData

/// Adds a Push / Pull / Legs starter set on first launch. Everything can be deleted.
@MainActor
enum SampleDataService {

    static func seedIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: SettingsKey.didSeedSampleData) else { return }
        defaults.set(true, forKey: SettingsKey.didSeedSampleData)

        // Don't add samples on top of data (e.g. a restored backup).
        let routineCount = (try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0
        guard routineCount == 0 else { return }
        seed(context: context)
    }

    /// Creates the sample routines. Reuses library exercises with the same name if they exist,
    /// so running it again (Settings → Add sample routines) doesn't duplicate exercises.
    static func seed(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var library = Dictionary(existing.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        let increment = AppSettings.defaultWeightIncrement

        func exercise(_ name: String, sets: Int = 3, reps: ClosedRange<Int>, rest: Int = 90, note: String = "") -> Exercise {
            if let found = library[name.lowercased()] { return found }
            let new = Exercise(name: name, targetSets: sets, repMin: reps.lowerBound, repMax: reps.upperBound,
                               restSeconds: rest, weightIncrement: increment, note: note)
            context.insert(new)
            library[name.lowercased()] = new
            return new
        }

        let push = [
            exercise("Bench Press", sets: 3, reps: 6...10, rest: 150, note: "Shoulder blades back and down"),
            exercise("Overhead Press", sets: 3, reps: 6...10, rest: 120),
            exercise("Incline Dumbbell Press", sets: 3, reps: 8...12, rest: 90),
            exercise("Lateral Raise", sets: 3, reps: 12...15, rest: 60),
            exercise("Triceps Pushdown", sets: 3, reps: 10...15, rest: 60)
        ]
        let pull = [
            exercise("Lat Pulldown", sets: 3, reps: 8...12, rest: 90, note: "Thigh pad: 3"),
            exercise("Barbell Row", sets: 3, reps: 6...10, rest: 120),
            exercise("Seated Cable Row", sets: 3, reps: 10...12, rest: 90),
            exercise("Face Pull", sets: 3, reps: 12...15, rest: 60),
            exercise("Dumbbell Curl", sets: 3, reps: 8...12, rest: 60)
        ]
        let legs = [
            exercise("Squat", sets: 3, reps: 5...8, rest: 180),
            exercise("Romanian Deadlift", sets: 3, reps: 8...10, rest: 120),
            exercise("Leg Press", sets: 3, reps: 10...12, rest: 120, note: "Seat position 4"),
            exercise("Leg Curl", sets: 3, reps: 10...12, rest: 75),
            exercise("Calf Raise", sets: 4, reps: 12...15, rest: 60)
        ]

        var index = RoutineService.nextSortIndex(context)
        for (name, exercises) in [("Push", push), ("Pull", pull), ("Legs", legs)] {
            let routine = Routine(name: name, sortIndex: index)
            index += 1
            context.insert(routine)
            RoutineService.add(exercises, to: routine, context: context)
        }
        WorkoutService.save(context)
    }
}
