import SwiftUI
import SwiftData

/// Finished workouts grouped by month, newest first.
struct HistoryListView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isFinished == true },
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    private struct MonthGroup: Identifiable {
        let month: Date
        let sessions: [WorkoutSession]
        var id: Date { month }
    }

    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: sessions) { session in
            calendar.dateInterval(of: .month, for: session.startedAt)?.start ?? session.startedAt
        }
        return byMonth.keys.sorted(by: >).map { month in
            MonthGroup(month: month, sessions: (byMonth[month] ?? []).sorted { $0.startedAt > $1.startedAt })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(group.sessions) { session in
                            NavigationLink {
                                WorkoutDetailView(session: session)
                            } label: {
                                HistoryRow(session: session, unit: unit)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                context.delete(group.sessions[index])
                            }
                            WorkoutService.save(context)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    Label("Exercise Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Finished workouts show up here."))
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.routineName)
                .font(.headline)
            Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Label(Fmt.duration(session.duration), systemImage: "clock")
                Label("\(session.completedSetCount) sets", systemImage: "checkmark.circle")
                Label(Fmt.volume(session.totalVolumeKg, unit: unit), systemImage: "scalemass")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
