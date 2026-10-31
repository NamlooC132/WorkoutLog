import Foundation

// Plain Codable copies of the SwiftData models, used for JSON export/import.
// Keeping these separate from the @Model classes means the file format stays
// stable even if the database schema changes later.

struct BackupFile: Codable {
    static let formatID = "workoutlog-backup"

    var format: String = BackupFile.formatID
    var version: Int = 1
    /// "full" (everything) or "routines" (routines + their exercises, no history).
    var kind: String
    var exportedAt: Date
    var exercises: [ExerciseDTO]
    var routines: [RoutineDTO]
    var workouts: [WorkoutDTO]
}

struct ExerciseDTO: Codable {
    var id: UUID
    var name: String
    var imageData: Data?          // encoded as base64 by JSONEncoder
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    var restSeconds: Int
    var weightIncrement: Double
    var note: String
    var createdAt: Date
}

struct RoutineDTO: Codable {
    var id: UUID
    var name: String
    var sortIndex: Int
    var createdAt: Date
    /// Exercise IDs in routine order.
    var exerciseIDs: [UUID]
}

struct WorkoutDTO: Codable {
    var id: UUID
    var routineName: String
    var routineID: UUID?
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var exercises: [WorkoutExerciseDTO]
}

struct WorkoutExerciseDTO: Codable {
    var id: UUID
    var exerciseID: UUID?
    var exerciseName: String
    var sortIndex: Int
    var sets: [SetDTO]
}

struct SetDTO: Codable {
    var id: UUID
    var position: Int
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
}

// MARK: - Model → DTO

extension ExerciseDTO {
    init(_ e: Exercise) {
        self.init(id: e.id, name: e.name, imageData: e.imageData, targetSets: e.targetSets,
                  repMin: e.repMin, repMax: e.repMax, restSeconds: e.restSeconds,
                  weightIncrement: e.weightIncrement, note: e.note, createdAt: e.createdAt)
    }

    func makeModel() -> Exercise {
        Exercise(id: id, name: name, imageData: imageData, targetSets: max(1, targetSets),
                 repMin: max(1, repMin), repMax: max(repMin, repMax),
                 restSeconds: RestTime.clamp(restSeconds), weightIncrement: weightIncrement,
                 note: note, createdAt: createdAt)
    }
}

extension RoutineDTO {
    init(_ r: Routine) {
        self.init(id: r.id, name: r.name, sortIndex: r.sortIndex, createdAt: r.createdAt,
                  exerciseIDs: r.exercises.map(\.id))
    }
}

extension WorkoutDTO {
    init(_ s: WorkoutSession) {
        self.init(
            id: s.id, routineName: s.routineName, routineID: s.routineID,
            startedAt: s.startedAt, endedAt: s.endedAt, notes: s.notes,
            exercises: s.orderedEntries.map { entry in
                WorkoutExerciseDTO(
                    id: entry.id, exerciseID: entry.exercise?.id, exerciseName: entry.displayName,
                    sortIndex: entry.sortIndex,
                    sets: entry.orderedSets.map {
                        SetDTO(id: $0.id, position: $0.position, weightKg: $0.weightKg,
                               reps: $0.reps, isCompleted: $0.isCompleted)
                    })
            })
    }
}
