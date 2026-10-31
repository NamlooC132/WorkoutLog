import SwiftUI
import SwiftData

/// App entry point.
/// Opens the on-device SwiftData database, seeds sample routines on first launch
/// and shares app-wide services (UI state, rest timer) through the environment.
@main
struct WorkoutLogApp: App {
    /// The single local database. No accounts, no servers, no iCloud.
    let container: ModelContainer

    @State private var appState = AppState()
    @State private var restTimer = RestTimerService()

    init() {
        AppSettings.registerDefaults()
        do {
            container = try ModelContainer(
                for: Routine.self, RoutineExercise.self, Exercise.self,
                WorkoutSession.self, WorkoutExercise.self, WorkoutSet.self
            )
        } catch {
            fatalError("Could not open the workout database: \(error)")
        }
        NotificationService.shared.configure()
        SampleDataService.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(restTimer)
        }
        .modelContainer(container)
    }
}
