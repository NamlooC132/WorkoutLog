import SwiftUI
import SwiftData

/// Inside a routine: the ordered exercise list and the big "Start Workout" button.
struct RoutineDetailView: View {
    let routine: Routine

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg

    @Query(filter: #Predicate<WorkoutSession> { $0.isFinished == false })
    private var activeSessions: [WorkoutSession]

    @State private var showingPicker = false
    @State private var editingExercise: Exercise?
    @State private var showingConflict = false
    @State private var showingRename = false
    @State private var renameText = ""

    init(routine: Routine) {
        self.routine = routine
    }

    var body: some View {
        List {
            Section {
                ForEach(routine.orderedItems) { item in
                    if let exercise = item.exercise {
                        Button {
                            editingExercise = exercise
                        } label: {
                            RoutineExerciseRow(exercise: exercise, unit: unit)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .onDelete { offsets in
                    RoutineService.removeItems(at: offsets, from: routine, context: context)
                }
                .onMove { source, destination in
                    RoutineService.moveItems(in: routine, from: source, to: destination, context: context)
                }

                Button {
                    showingPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Tap to edit · hold and drag to reorder · swipe left to remove from this routine.")
            }
        }
        .navigationTitle(routine.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        renameText = routine.name
                        showingRename = true
                    }
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        RoutineService.duplicate(routine, context: context)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                EditButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            startButton
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView(title: "Add to \(routine.name)") { exercises in
                RoutineService.add(exercises, to: routine, context: context)
            }
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditorView(exercise: exercise)
        }
        .alert("Rename Routine", isPresented: $showingRename) {
            TextField("Name", text: $renameText)
            Button("Save") { RoutineService.rename(routine, to: renameText, context: context) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("A workout is already in progress", isPresented: $showingConflict) {
            Button("Resume Current Workout") { appState.isWorkoutPresented = true }
            Button("Discard It & Start \(routine.name)", role: .destructive) {
                for session in activeSessions { WorkoutService.delete(session, context: context) }
                startWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can only run one workout at a time.")
        }
    }

    private var startButton: some View {
        Button {
            NotificationService.shared.requestPermissionIfNeeded() // first use → permission prompt
            if activeSessions.isEmpty {
                startWorkout()
            } else {
                showingConflict = true
            }
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(routine.items.isEmpty)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func startWorkout() {
        WorkoutService.start(routine: routine, context: context)
        Haptics.success()
        appState.isWorkoutPresented = true
    }
}

/// One exercise line inside a routine.
private struct RoutineExerciseRow: View {
    let exercise: Exercise
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(imageData: exercise.imageData, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                Text(exercise.targetSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !exercise.note.isEmpty {
                    Label(exercise.note, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if case .increase = ProgressionService.overloadStatus(for: exercise, unit: unit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Ready to add weight")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
