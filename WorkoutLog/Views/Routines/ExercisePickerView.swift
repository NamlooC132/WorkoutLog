import SwiftUI
import SwiftData

/// Pick one or more exercises from the shared library (or create a new one).
struct ExercisePickerView: View {
    let title: String
    let onAdd: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    /// Selected IDs in the order they were tapped (that's the order they're added in).
    @State private var selectedIDs: [UUID] = []
    @State private var showingNewExercise = false

    init(title: String = "Add Exercises", onAdd: @escaping ([Exercise]) -> Void) {
        self.title = title
        self.onAdd = onAdd
    }

    private var filtered: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingNewExercise = true
                    } label: {
                        Label("Create New Exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(minHeight: 44)
                    }
                }

                Section("Library") {
                    ForEach(filtered) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseThumbnail(imageData: exercise.imageData, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).font(.body.weight(.medium))
                                    Text(exercise.targetSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedIDs.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selectedIDs.contains(exercise.id) ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedIDs.isEmpty ? "Add" : "Add (\(selectedIDs.count))") {
                        let chosen = selectedIDs.compactMap { id in exercises.first { $0.id == id } }
                        onAdd(chosen)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewExercise) {
                ExerciseEditorView(exercise: nil) { newExercise in
                    selectedIDs.append(newExercise.id) // auto-select what you just created
                }
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if let index = selectedIDs.firstIndex(of: exercise.id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(exercise.id)
        }
    }
}
