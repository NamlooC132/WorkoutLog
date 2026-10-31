import SwiftUI
import SwiftData

/// The live workout screen.
///
/// Each exercise is a section: header (photo, name, "Last time", overload banner),
/// then one big row per set (weight − / +, reps, checkmark). Ticking a set starts the
/// rest timer, which appears at the bottom.
struct ActiveWorkoutView: View {
    @Environment(AppState.self) private var appState
    @Environment(RestTimerService.self) private var restTimer
    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg

    @State private var vm: ActiveWorkoutViewModel
    @State private var showingFinishDialog = false
    @State private var showingDiscardDialog = false
    @State private var showingExercisePicker = false

    init(session: WorkoutSession, context: ModelContext) {
        _vm = State(initialValue: ActiveWorkoutViewModel(session: session, context: context))
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection

                ForEach(vm.entries) { entry in
                    exerciseSection(entry)
                }

                Section {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(vm.session.routineName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if restTimer.isRunning {
                    RestTimerView()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: restTimer.isRunning)
            .confirmationDialog("Finish workout?", isPresented: $showingFinishDialog, titleVisibility: .visible) {
                finishButtons
            } message: {
                Text("\(vm.completedSetCount) of \(vm.totalSetCount) sets done · \(Fmt.duration(vm.session.duration))")
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingDiscardDialog, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) { discard() }
                Button("Keep Training", role: .cancel) {}
            } message: {
                Text("Everything logged in this session will be deleted.")
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(title: "Add to Workout") { exercises in
                    vm.addExercises(exercises)
                }
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration").font(.caption).foregroundStyle(.secondary)
                    Text(vm.session.startedAt, style: .timer)
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sets done").font(.caption).foregroundStyle(.secondary)
                    Text("\(vm.completedSetCount) / \(vm.totalSetCount)")
                        .font(.title2.bold().monospacedDigit())
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func exerciseSection(_ entry: WorkoutExercise) -> some View {
        Section {
            WorkoutExerciseHeader(
                entry: entry,
                unit: unit,
                onApply: { vm.applySuggestion($0, to: entry) },
                onDismissSuggestion: { vm.dismissSuggestion(for: entry) },
                onRemove: { vm.removeEntry(entry) }
            )

            SetColumnHeader(unit: unit)

            ForEach(Array(entry.orderedSets.enumerated()), id: \.element.id) { index, set in
                SetRowView(
                    set: set,
                    number: index + 1,
                    unit: unit,
                    increment: entry.exercise?.weightIncrement ?? AppSettings.defaultWeightIncrement
                ) {
                    vm.toggleCompletion(of: set, in: entry, timer: restTimer)
                }
                .listRowBackground(set.isCompleted ? Color.green.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        vm.removeSet(set, from: entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            HStack {
                Button {
                    vm.addSet(to: entry)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                Spacer()
                Button(role: .destructive) {
                    vm.removeLastSet(from: entry)
                } label: {
                    Label("Remove Set", systemImage: "minus")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .disabled(entry.sets.isEmpty)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Toolbar & dialogs

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Minimize", systemImage: "chevron.down") {
                    hideKeyboard()
                    appState.isWorkoutPresented = false
                }
                Button("Discard Workout", systemImage: "trash", role: .destructive) {
                    showingDiscardDialog = true
                }
            } label: {
                Image(systemName: "chevron.down.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Workout options")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Finish") {
                hideKeyboard()
                showingFinishDialog = true
            }
            .fontWeight(.bold)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { hideKeyboard() }
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var finishButtons: some View {
        if vm.uncheckedSetCount > 0 {
            Button("Finish – mark all sets done") { finish(discardUnchecked: false) }
            if vm.completedSetCount > 0 {
                Button("Finish – drop \(vm.uncheckedSetCount) unchecked set\(vm.uncheckedSetCount == 1 ? "" : "s")") {
                    finish(discardUnchecked: true)
                }
            }
        } else if vm.completedSetCount > 0 {
            Button("Finish Workout") { finish(discardUnchecked: false) }
        } else {
            // Nothing logged at all – there's nothing to save.
            Button("Discard Empty Workout", role: .destructive) { discard() }
        }
        Button("Keep Training", role: .cancel) {}
    }

    private func finish(discardUnchecked: Bool) {
        restTimer.skip()
        appState.isWorkoutPresented = false
        vm.finish(discardUnchecked: discardUnchecked)
        Haptics.success()
    }

    /// Close the screen first, then delete, so no view is still showing deleted data.
    private func discard() {
        restTimer.skip()
        appState.isWorkoutPresented = false
        let model = vm
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            model.discard()
        }
    }
}

/// Column titles above the set rows (aligned with `SetRowView`).
private struct SetColumnHeader: View {
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 6) {
            Text("SET").frame(width: 24)
            Text("WEIGHT (\(unit.symbol))").frame(maxWidth: .infinity)
            Text("REPS").frame(width: 64)
            Text("DONE").frame(width: 48)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .listRowSeparator(.hidden, edges: .bottom)
    }
}
