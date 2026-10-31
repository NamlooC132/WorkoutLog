import SwiftUI
import SwiftData
import Charts

/// Per-exercise progress: personal record, top-weight chart and every past session.
struct ExerciseProgressView: View {
    let exercise: Exercise

    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg
    @State private var showingEditor = false

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    var body: some View {
        let history = ProgressionService.finishedEntries(for: exercise)
        let record = ProgressionService.personalRecord(for: exercise)
        let points = ProgressionService.topWeightHistory(for: exercise)

        List {
            // Header
            Section {
                HStack(spacing: 14) {
                    ExerciseThumbnail(imageData: exercise.imageData, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name).font(.title2.bold())
                        Text(exercise.targetSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !exercise.note.isEmpty {
                            Label(exercise.note, systemImage: "note.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Personal record
            Section("Personal record") {
                if let record {
                    PersonalRecordCard(record: record, unit: unit)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                } else {
                    Text("Complete a workout with this exercise to set your first record.")
                        .foregroundStyle(.secondary)
                }
            }

            // Chart
            Section("Top weight over time") {
                if points.isEmpty {
                    Text("No data yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", unit.fromKg(point.topWeightKg))
                        )
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", unit.fromKg(point.topWeightKg))
                        )
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel(unit.symbol)
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 220)
                    .padding(.vertical, 8)
                }
            }

            // Past sessions
            Section("Past sessions") {
                if history.isEmpty {
                    Text("No sessions yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(history) { entry in
                    if let session = entry.session {
                        NavigationLink {
                            WorkoutDetailView(session: session)
                        } label: {
                            PastSessionRow(entry: entry, session: session, unit: unit,
                                           isRecord: ProgressionService.entry(entry, contains: record))
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            ExerciseEditorView(exercise: exercise)
        }
    }
}

/// Highlighted PR card.
private struct PersonalRecordCard: View {
    let record: PersonalRecord
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.weight(record.weightKg, unit: unit)) × \(record.reps)")
                    .font(.title2.bold().monospacedDigit())
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Estimated 1RM: \(Fmt.weight(record.estimatedOneRepMaxKg, unit: unit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PastSessionRow: View {
    let entry: WorkoutExercise
    let session: WorkoutSession
    let unit: WeightUnit
    let isRecord: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                if isRecord {
                    Label("PR", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(session.routineName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(ProgressionService.summary(
                of: entry.completedSets.map { SetSnapshot(weightKg: $0.weightKg, reps: $0.reps) },
                unit: unit))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
