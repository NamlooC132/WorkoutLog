import SwiftUI
import SwiftData

/// Tab bar (Routines · History · Settings) plus the live-workout layer on top.
///
/// Restoring a workout: an unfinished `WorkoutSession` in the database means a
/// workout is in progress. On launch we find it and reopen the workout screen.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(RestTimerService.self) private var restTimer

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isFinished == false },
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var activeSessions: [WorkoutSession]

    var body: some View {
        @Bindable var appState = appState

        TabView {
            RoutinesListView()
                .tabItem { Label("Routines", systemImage: "folder.fill") }
            HistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        // "Workout in progress" bar when the workout is minimized.
        .safeAreaInset(edge: .top, spacing: 0) {
            if let session = activeSessions.first, !appState.isWorkoutPresented {
                ResumeWorkoutBar(session: session) {
                    appState.isWorkoutPresented = true
                }
            }
        }
        .fullScreenCover(isPresented: $appState.isWorkoutPresented) {
            if let session = activeSessions.first {
                ActiveWorkoutView(session: session, context: context)
                    .id(session.id)
            } else {
                // Only visible for a split second while a workout is being created or closed.
                ContentUnavailableView {
                    Label("No active workout", systemImage: "figure.strengthtraining.traditional")
                } actions: {
                    Button("Close") { appState.isWorkoutPresented = false }
                }
            }
        }
        .task {
            // Reopen an unfinished workout after the app was closed.
            if !activeSessions.isEmpty {
                appState.isWorkoutPresented = true
            }
            restTimer.handleBecameActive()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restTimer.handleBecameActive()
            } else {
                // Leaving the foreground: flush everything to disk.
                WorkoutService.save(context)
            }
        }
    }
}
