import Foundation

/// A plain value copy of a logged set.
struct SetSnapshot: Hashable {
    let weightKg: Double
    let reps: Int
}

/// What the user lifted the last time they trained an exercise.
struct LastPerformance {
    let date: Date
    /// Completed sets only, in the order they were performed.
    let sets: [SetSnapshot]
}

/// A "time to add weight" recommendation.
struct OverloadSuggestion: Equatable {
    let repMax: Int
    let lastWeightKg: Double
    let suggestedWeightKg: Double
}

/// Result of checking the last session against the rep range.
enum OverloadStatus {
    /// Never trained this exercise (no banner).
    case noHistory
    /// Hit the top of the rep range on every set at one weight → add weight.
    case increase(OverloadSuggestion)
    /// Didn't hit max reps on every set → keep the same weight.
    case keepWeight(repMax: Int)
}

/// Heaviest set ever logged for an exercise.
struct PersonalRecord {
    let weightKg: Double
    let reps: Int
    let date: Date

    /// Epley estimate of the one-rep max.
    var estimatedOneRepMaxKg: Double {
        reps <= 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }
}

/// One point on the progress chart.
struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let topWeightKg: Double
}

/// Pure functions that read workout history. No side effects, no saving.
enum ProgressionService {

    private static let epsilon = 0.0001

    /// Finished workout entries for an exercise that have at least one completed set, newest first.
    static func finishedEntries(for exercise: Exercise) -> [WorkoutExercise] {
        exercise.workoutEntries
            .filter { entry in
                guard let session = entry.session, session.isFinished else { return false }
                return entry.sets.contains(where: \.isCompleted)
            }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
    }

    /// The most recent finished session for this exercise (the in-progress workout is never included).
    static func lastPerformance(for exercise: Exercise) -> LastPerformance? {
        guard let entry = finishedEntries(for: exercise).first,
              let date = entry.session?.startedAt else { return nil }
        let sets = entry.completedSets.map { SetSnapshot(weightKg: $0.weightKg, reps: $0.reps) }
        return LastPerformance(date: date, sets: sets)
    }

    /// "60 kg × 10, 10, 9" – consecutive sets with the same weight are grouped.
    /// Mixed weights read as "60 kg × 10, 10 · 55 kg × 12".
    static func summary(of sets: [SetSnapshot], unit: WeightUnit) -> String {
        var groups: [(weightKg: Double, reps: [Int])] = []
        for set in sets {
            if let last = groups.last, abs(last.weightKg - set.weightKg) < epsilon {
                groups[groups.count - 1].reps.append(set.reps)
            } else {
                groups.append((weightKg: set.weightKg, reps: [set.reps]))
            }
        }
        return groups
            .map { "\(Fmt.weight($0.weightKg, unit: unit)) × \($0.reps.map(String.init).joined(separator: ", "))" }
            .joined(separator: " · ")
    }

    /// Progressive-overload rule:
    /// If, in the last session, every completed (working) set was at the same weight AND
    /// reached the top of the rep range, suggest last weight + 2.5 kg (or + 5 lbs).
    static func overloadStatus(for exercise: Exercise, unit: WeightUnit) -> OverloadStatus {
        guard let last = lastPerformance(for: exercise), let first = last.sets.first else {
            return .noHistory
        }
        let sameWeight = last.sets.allSatisfy { abs($0.weightKg - first.weightKg) < epsilon }
        let hitMaxEverySet = last.sets.allSatisfy { $0.reps >= exercise.repMax }
        guard sameWeight, hitMaxEverySet else {
            return .keepWeight(repMax: exercise.repMax)
        }
        // Work in the display unit so the jump is exactly 2.5 kg or exactly 5 lbs.
        let lastDisplay = (unit.fromKg(first.weightKg) * 100).rounded() / 100
        let suggestedKg = unit.toKg(lastDisplay + unit.progressionStep)
        return .increase(OverloadSuggestion(
            repMax: exercise.repMax,
            lastWeightKg: first.weightKg,
            suggestedWeightKg: suggestedKg
        ))
    }

    /// Heaviest completed set ever (ties broken by more reps).
    static func personalRecord(for exercise: Exercise) -> PersonalRecord? {
        var best: PersonalRecord?
        for entry in finishedEntries(for: exercise) {
            guard let date = entry.session?.startedAt else { continue }
            for set in entry.sets where set.isCompleted {
                guard let current = best else {
                    best = PersonalRecord(weightKg: set.weightKg, reps: set.reps, date: date)
                    continue
                }
                let heavier = set.weightKg > current.weightKg + epsilon
                let sameWeightMoreReps = abs(set.weightKg - current.weightKg) < epsilon && set.reps > current.reps
                if heavier || sameWeightMoreReps {
                    best = PersonalRecord(weightKg: set.weightKg, reps: set.reps, date: date)
                }
            }
        }
        return best
    }

    /// Top weight per session, oldest first, for the line chart.
    static func topWeightHistory(for exercise: Exercise) -> [ProgressPoint] {
        finishedEntries(for: exercise)
            .reversed()
            .compactMap { entry in
                guard let date = entry.session?.startedAt,
                      let top = entry.completedSets.map(\.weightKg).max() else { return nil }
                return ProgressPoint(date: date, topWeightKg: top)
            }
    }

    /// Whether a given entry contains the personal-record set.
    static func entry(_ entry: WorkoutExercise, contains record: PersonalRecord?) -> Bool {
        guard let record, entry.session?.startedAt == record.date else { return false }
        return entry.completedSets.contains {
            abs($0.weightKg - record.weightKg) < epsilon && $0.reps == record.reps
        }
    }
}
