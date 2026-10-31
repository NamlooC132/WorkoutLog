import Observation

/// Small piece of shared UI state.
@Observable
final class AppState {
    /// Whether the live workout screen is on top. The workout itself lives in the
    /// database, so minimizing (or killing the app) never loses it.
    var isWorkoutPresented = false
}
