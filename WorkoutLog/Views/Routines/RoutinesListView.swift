import SwiftUI
import SwiftData

/// Home screen: routines shown as "folders".
/// Create (+), rename / duplicate / delete (long-press or swipe), reorder (drag).
struct RoutinesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.sortIndex) private var routines: [Routine]

    @State private var showingNewRoutine = false
    @State private var newRoutineName = ""
    @State private var renaming: Routine?
    @State private var renameText = ""
    @State private var deleting: Routine?
    @State private var path: [Routine] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(routines) { routine in
                    NavigationLink(value: routine) {
                        RoutineRow(routine: routine)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleting = routine } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { startRename(routine) } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button { RoutineService.duplicate(routine, context: context) } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { startRename(routine) }
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            RoutineService.duplicate(routine, context: context)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) { deleting = routine }
                    }
                }
                .onMove { source, destination in
                    RoutineService.move(routines, from: source, to: destination, context: context)
                }
            }
            .navigationTitle("Routines")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !routines.isEmpty { EditButton() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Label("Exercise Library", systemImage: "books.vertical")
                    }
                    Button {
                        newRoutineName = ""
                        showingNewRoutine = true
                    } label: {
                        Label("New Routine", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No routines yet", systemImage: "folder.badge.plus")
                    } description: {
                        Text("Create a routine once, then just open it and train.")
                    } actions: {
                        Button("New Routine") { showingNewRoutine = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .alert("New Routine", isPresented: $showingNewRoutine) {
                TextField("e.g. Upper Body A", text: $newRoutineName)
                Button("Create") {
                    let routine = RoutineService.create(name: newRoutineName, context: context)
                    path.append(routine) // open it right away to add exercises
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename Routine", isPresented: isRenaming) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let renaming { RoutineService.rename(renaming, to: renameText, context: context) }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .confirmationDialog("Delete routine?", isPresented: isDeleting, titleVisibility: .visible, presenting: deleting) { routine in
                Button("Delete “\(routine.name)”", role: .destructive) {
                    RoutineService.delete(routine, context: context)
                    deleting = nil
                }
            } message: { _ in
                Text("Your exercises stay in the library and your workout history is kept.")
            }
        }
    }

    // MARK: - Helpers

    private func startRename(_ routine: Routine) {
        renameText = routine.name
        renaming = routine
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
}

/// A routine "folder" card.
private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        let names = routine.exercises.map(\.name)
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.headline)
                Text(names.isEmpty
                     ? "No exercises yet"
                     : "\(names.count) exercise\(names.count == 1 ? "" : "s") · \(names.prefix(3).joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}
