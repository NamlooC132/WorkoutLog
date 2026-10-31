import Foundation
import SwiftData

/// Exports the database to a JSON file and imports it back (merging, never overwriting).
///
/// Two export flavours:
/// - **Full backup**: exercises (incl. photos), routines and all finished workouts.
///   Use it to move to a new phone.
/// - **Routines only**: routines + the exercises they use, no history.
///   Use it to share routines with friends.
@MainActor
enum BackupService {

    enum BackupError: LocalizedError {
        case notABackup
        var errorDescription: String? { "This file isn't a Workout Log backup." }
    }

    struct ImportSummary {
        var exercisesAdded = 0
        var routinesAdded = 0
        var workoutsAdded = 0
        var skipped = 0

        var message: String {
            var lines = [
                "Routines added: \(routinesAdded)",
                "Exercises added: \(exercisesAdded)",
                "Workouts added: \(workoutsAdded)"
            ]
            if skipped > 0 { lines.append("Already on this phone (skipped): \(skipped)") }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Export

    static func makeBackup(context: ModelContext, includeHistory: Bool) throws -> BackupFile {
        let routines = try context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.sortIndex)]))

        var exercises: [Exercise] = []
        var workouts: [WorkoutSession] = []

        if includeHistory {
            exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
            let finished = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { $0.isFinished == true },
                sortBy: [SortDescriptor(\.startedAt)]
            )
            workouts = try context.fetch(finished)
        } else {
            // Only the exercises referenced by routines.
            var seen = Set<UUID>()
            for routine in routines {
                for exercise in routine.exercises where !seen.contains(exercise.id) {
                    seen.insert(exercise.id)
                    exercises.append(exercise)
                }
            }
        }

        return BackupFile(
            kind: includeHistory ? "full" : "routines",
            exportedAt: .now,
            exercises: exercises.map { ExerciseDTO($0) },
            routines: routines.map { RoutineDTO($0) },
            workouts: workouts.map { WorkoutDTO($0) }
        )
    }

    /// Writes the backup to a temporary file and returns its URL (for the share sheet).
    static func exportFile(context: ModelContext, includeHistory: Bool) throws -> URL {
        let backup = try makeBackup(context: context, includeHistory: includeHistory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let prefix = includeHistory ? "WorkoutLog-Backup" : "WorkoutLog-Routines"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(Fmt.fileDate(.now)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    /// Reads a JSON file picked in the Files app and merges it into the database.
    static func importFile(at url: URL, context: ModelContext) throws -> ImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: BackupFile
        do {
            backup = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.notABackup
        }
        guard backup.format == BackupFile.formatID else { throw BackupError.notABackup }
        return try merge(backup, into: context)
    }

    /// Merge rules (nothing on the phone is ever overwritten or deleted):
    /// - Exercises: matched by ID, then by name (case-insensitive), so a friend's
    ///   "Bench Press" joins your existing "Bench Press" and shares its history.
    /// - Routines and workouts: skipped if the same ID already exists.
    static func merge(_ backup: BackupFile, into context: ModelContext) throws -> ImportSummary {
        var summary = ImportSummary()

        // Exercises
        let existingExercises = try context.fetch(FetchDescriptor<Exercise>())
        var byID = Dictionary(existingExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var byName = Dictionary(existingExercises.map { (nameKey($0.name), $0) }, uniquingKeysWith: { first, _ in first })
        var resolved: [UUID: Exercise] = [:]

        for dto in backup.exercises {
            if let match = byID[dto.id] ?? byName[nameKey(dto.name)] {
                resolved[dto.id] = match
                if match.imageData == nil, let image = dto.imageData { match.imageData = image }
                summary.skipped += 1
                continue
            }
            let exercise = dto.makeModel()
            context.insert(exercise)
            resolved[dto.id] = exercise
            byID[exercise.id] = exercise
            byName[nameKey(exercise.name)] = exercise
            summary.exercisesAdded += 1
        }

        // Routines
        let existingRoutines = try context.fetch(FetchDescriptor<Routine>())
        let existingRoutineIDs = Set(existingRoutines.map(\.id))
        let existingRoutineNames = Set(existingRoutines.map { nameKey($0.name) })
        var nextIndex = (existingRoutines.map(\.sortIndex).max() ?? -1) + 1

        for dto in backup.routines.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            if existingRoutineIDs.contains(dto.id) {
                summary.skipped += 1
                continue
            }
            let name = existingRoutineNames.contains(nameKey(dto.name)) ? "\(dto.name) (imported)" : dto.name
            let routine = Routine(id: dto.id, name: name, sortIndex: nextIndex, createdAt: dto.createdAt)
            nextIndex += 1
            context.insert(routine)
            RoutineService.add(dto.exerciseIDs.compactMap { resolved[$0] }, to: routine, context: context)
            summary.routinesAdded += 1
        }

        // Workouts
        let existingSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let existingSessionIDs = Set(existingSessions.map(\.id))

        for dto in backup.workouts {
            if existingSessionIDs.contains(dto.id) {
                summary.skipped += 1
                continue
            }
            let session = WorkoutSession(
                id: dto.id, routineName: dto.routineName, routineID: dto.routineID,
                startedAt: dto.startedAt, endedAt: dto.endedAt ?? dto.startedAt,
                isFinished: true, notes: dto.notes
            )
            context.insert(session)

            for entryDTO in dto.exercises {
                let entry = WorkoutExercise(sortIndex: entryDTO.sortIndex, exerciseName: entryDTO.exerciseName,
                                            progressionApplied: true)
                context.insert(entry)
                if let exerciseID = entryDTO.exerciseID {
                    entry.exercise = resolved[exerciseID] ?? byID[exerciseID]
                }
                session.entries.append(entry)

                for setDTO in entryDTO.sets {
                    let set = WorkoutSet(position: setDTO.position, weightKg: setDTO.weightKg,
                                         reps: setDTO.reps, isCompleted: setDTO.isCompleted)
                    context.insert(set)
                    entry.sets.append(set)
                }
            }
            summary.workoutsAdded += 1
        }

        try context.save()
        return summary
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
