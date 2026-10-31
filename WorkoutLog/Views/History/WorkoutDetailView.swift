import SwiftUI
import SwiftData

/// Full details of a past workout. "Edit" lets you fix weights/reps, add or delete
/// sets, remove exercises, rename, or change the date/time.
struct WorkoutDetailView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg

    @State private var isEditing = false
    @State private var showingDelete = false

    init(session: WorkoutSession) {
        self.session = session
    }

    var body: some View {
        List {
            summarySection

            ForEach(session.orderedEntries) { entry in
                Section {
                    entryHeader(entry)

                    ForEach(Array(entry.orderedSets.enumerated()), id: \.element.id) { index, set in
                        if isEditing {
                            EditableSetRow(set: set, number: index + 1, unit: unit)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        WorkoutService.removeSet(set, from: entry, context: context)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else {
                            HStack {
                                Text("Set \(index + 1)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Fmt.weight(set.weightKg, unit: unit)) × \(set.reps)")
                                    .font(.body.monospacedDigit().weight(.semibold))
                            }
                        }
                    }

                    if isEditing {
                        Button {
                            WorkoutService.addSet(to: entry, completed: true, context: context)
                        } label: {
                            Label("Add Set", systemImage: "plus")
                        }
                        Button(role: .destructive) {
                            WorkoutService.removeEntry(entry, from: session, context: context)
                        } label: {
                            Label("Remove Exercise", systemImage: "trash")
                        }
                    }
                }
            }

            if !isEditing {
                Section {
                    Button("Delete Workout", role: .destructive) { showingDelete = true }
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(session.routineName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        hideKeyboard()
                        WorkoutService.save(context)
                    }
                    withAnimation { isEditing.toggle() }
                }
                .fontWeight(isEditing ? .bold : .regular)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) { deleteWorkout() }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var summarySection: some View {
        Section {
            if isEditing {
                TextField("Workout name", text: $session.routineName)
                    .font(.headline)
                DatePicker("Started", selection: $session.startedAt)
                DatePicker("Finished", selection: endDateBinding, in: session.startedAt...)
            } else {
                LabeledContent("Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: Fmt.duration(session.duration))
                LabeledContent("Sets", value: "\(session.completedSetCount)")
                LabeledContent("Volume", value: Fmt.volume(session.totalVolumeKg, unit: unit))
            }
        }
    }

    @ViewBuilder
    private func entryHeader(_ entry: WorkoutExercise) -> some View {
        let content = HStack(spacing: 12) {
            ExerciseThumbnail(imageData: entry.exercise?.imageData, size: 40)
            Text(entry.displayName)
                .font(.headline)
        }
        if let exercise = entry.exercise, !isEditing {
            NavigationLink {
                ExerciseProgressView(exercise: exercise)
            } label: {
                content
            }
        } else {
            content
        }
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { session.endedAt ?? session.startedAt },
            set: { session.endedAt = $0 }
        )
    }

    /// Leave the screen first, then delete (avoids showing a deleted record).
    private func deleteWorkout() {
        let target = session
        let ctx = context
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            WorkoutService.delete(target, context: ctx)
        }
    }
}

/// Editable weight × reps row for a past workout.
private struct EditableSetRow: View {
    @Bindable var set: WorkoutSet
    let number: Int
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)
            NumberInputField(value: SetBindings.weight(set, unit: unit), allowsDecimal: true, minHeight: 44)
            Text(unit.symbol).foregroundStyle(.secondary)
            Text("×").foregroundStyle(.secondary)
            NumberInputField(value: SetBindings.reps(set), allowsDecimal: false, minHeight: 44)
                .frame(width: 70)
        }
    }
}
