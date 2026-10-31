import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit a library exercise: name, photo, sets, rep range, rest, increment, note.
struct ExerciseEditorView: View {
    private let onSave: ((Exercise) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.unit) private var unit: WeightUnit = .kg

    @State private var vm: ExerciseEditorViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false

    /// - Parameters:
    ///   - exercise: `nil` to create a new exercise.
    ///   - onSave: called with the saved exercise.
    init(exercise: Exercise?, onSave: ((Exercise) -> Void)? = nil) {
        _vm = State(initialValue: ExerciseEditorViewModel(exercise: exercise))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $vm.name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .frame(minHeight: 44)
                    photoRow
                }

                Section {
                    Stepper(value: $vm.targetSets, in: 1...10) {
                        LabeledContent("Sets", value: "\(vm.targetSets)")
                    }
                    Stepper(value: $vm.repMin, in: 1...max(1, vm.repMax)) {
                        LabeledContent("Min reps", value: "\(vm.repMin)")
                    }
                    Stepper(value: $vm.repMax, in: max(1, vm.repMin)...50) {
                        LabeledContent("Max reps", value: "\(vm.repMax)")
                    }
                } header: {
                    Text("Target")
                } footer: {
                    Text("Hit \(vm.repMax) reps on every set and the app suggests adding \(Fmt.number(unit.progressionStep)) \(unit.symbol) next time.")
                }

                Section {
                    Stepper(value: $vm.restSeconds, in: RestTime.range, step: RestTime.step) {
                        LabeledContent("Rest time", value: Fmt.rest(vm.restSeconds))
                    }
                    Picker("Weight step (−/+)", selection: $vm.weightIncrement) {
                        ForEach(vm.incrementOptions, id: \.self) { value in
                            Text("\(Fmt.number(value)) \(unit.symbol)").tag(value)
                        }
                    }
                } header: {
                    Text("Rest & weight")
                } footer: {
                    Text("Rest changes in 15-second steps.")
                }

                Section("Note") {
                    TextField("e.g. seat height 4", text: $vm.note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if vm.routineCount > 1 {
                    Section {
                        Label("This exercise is used in \(vm.routineCount) routines. Changes apply to all of them.",
                              systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(vm.isEditing ? "Edit Exercise" : "New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = vm.save(in: context)
                        onSave?(exercise)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!vm.canSave)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    vm.imageData = ImageService.thumbnailData(from: image)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var photoRow: some View {
        HStack(spacing: 16) {
            ExerciseThumbnail(imageData: vm.imageData, size: 64)
            VStack(alignment: .leading, spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(vm.imageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
                if vm.imageData != nil {
                    Button(role: .destructive) {
                        vm.imageData = nil
                        photoItem = nil
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        vm.imageData = ImageService.thumbnailData(from: image)
    }
}
