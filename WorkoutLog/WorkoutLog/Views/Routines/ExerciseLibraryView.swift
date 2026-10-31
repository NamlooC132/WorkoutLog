import SwiftUI
import SwiftData

/// Every exercise you've created. Tap one to see its history, PR and chart.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var showingNewExercise = false
    @State private var deleting: Exercise?

    private var filtered: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { exercise in
                NavigationLink {
                    ExerciseProgressView(exercise: exercise)
                } label: {
                    HStack(spacing: 12) {
                        ExerciseThumbnail(imageData: exercise.imageData, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).font(.body.weight(.semibold))
                            Text(usageText(exercise))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .swipeActions {
                    Button(role: .destructive) { deleting = exercise } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .toolbar {
            Button {
                showingNewExercise = true
            } label: {
                Label("New Exercise", systemImage: "plus")
            }
        }
        .overlay {
            if exercises.isEmpty {
                ContentUnavailableView("No exercises", systemImage: "dumbbell",
                                       description: Text("Tap + to create your first exercise."))
            }
        }
        .sheet(isPresented: $showingNewExercise) {
            ExerciseEditorView(exercise: nil)
        }
        .confirmationDialog("Delete exercise?", isPresented: isDeleting, titleVisibility: .visible, presenting: deleting) { exercise in
            Button("Delete “\(exercise.name)”", role: .destructive) {
                context.delete(exercise)
                WorkoutService.save(context)
                deleting = nil
            }
        } message: { _ in
            Text("It will be removed from every routine. Past workouts keep their logged sets.")
        }
    }

    private func usageText(_ exercise: Exercise) -> String {
        let routines = exercise.routineItems.count
        let sessions = ProgressionService.finishedEntries(for: exercise).count
        return "In \(routines) routine\(routines == 1 ? "" : "s") · \(sessions) workout\(sessions == 1 ? "" : "s") logged"
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}
