import Foundation
import Observation

/// The single app-wide rest timer.
///
/// Design: instead of counting down a number, we store the *end date*. The remaining
/// time is always `endDate - now`, so the timer stays correct across backgrounding,
/// locking the phone, or even the app being killed (the end date is persisted).
/// A local notification is scheduled for the same end date so the user is alerted
/// when the app isn't on screen.
@MainActor
@Observable
final class RestTimerService {
    private(set) var endDate: Date?
    /// Total length of the current rest (used for the progress bar).
    private(set) var totalSeconds: Int = 0
    private(set) var exerciseName: String = ""

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let endDate = "restTimer.endDate"
        static let total = "restTimer.total"
        static let name = "restTimer.name"
    }

    init() {
        restore()
    }

    var isRunning: Bool { endDate != nil }

    func remaining(at date: Date = .now) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(date))
    }

    /// Starts (or restarts) the countdown.
    func start(seconds: Int, exerciseName: String) {
        guard seconds > 0 else { return }
        self.exerciseName = exerciseName
        totalSeconds = seconds
        endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
        timerChanged()
    }

    /// −15 s / +15 s buttons.
    func adjust(by delta: Int) {
        guard let current = endDate else { return }
        let newRemaining = remaining() + TimeInterval(delta)
        guard newRemaining > 0.5 else {
            skip()
            return
        }
        endDate = current.addingTimeInterval(TimeInterval(delta))
        totalSeconds = max(totalSeconds + delta, Int(newRemaining.rounded(.up)))
        timerChanged()
    }

    /// Stops the timer without an alert.
    func skip() {
        endDate = nil
        totalSeconds = 0
        stopTicker()
        NotificationService.shared.cancelRestNotification()
        persist()
    }

    /// Called when the app comes back to the foreground.
    /// If rest ended while we were away, the notification already alerted the user,
    /// so we just clear the timer quietly.
    func handleBecameActive() {
        guard let endDate else { return }
        if endDate <= .now {
            skip()
        } else {
            startTicker()
        }
    }

    // MARK: - Private

    private func timerChanged() {
        persist()
        startTicker()
        NotificationService.shared.scheduleRestNotification(in: remaining(), exerciseName: exerciseName)
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let service = self else { return }
            Task { @MainActor in service.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let endDate else {
            stopTicker()
            return
        }
        guard endDate <= .now else { return }
        // Time's up while the app is open: chime + vibrate, and cancel the
        // notification so it doesn't fire a second time.
        self.endDate = nil
        totalSeconds = 0
        stopTicker()
        persist()
        NotificationService.shared.cancelRestNotification()
        Haptics.restFinished()
    }

    private func persist() {
        if let endDate {
            defaults.set(endDate, forKey: Keys.endDate)
            defaults.set(totalSeconds, forKey: Keys.total)
            defaults.set(exerciseName, forKey: Keys.name)
        } else {
            defaults.removeObject(forKey: Keys.endDate)
            defaults.removeObject(forKey: Keys.total)
            defaults.removeObject(forKey: Keys.name)
        }
    }

    /// Resumes a timer that was running when the app was killed.
    private func restore() {
        guard let saved = defaults.object(forKey: Keys.endDate) as? Date else { return }
        if saved > .now {
            endDate = saved
            totalSeconds = defaults.integer(forKey: Keys.total)
            exerciseName = defaults.string(forKey: Keys.name) ?? ""
            startTicker()
        } else {
            persist() // clears the stale values
        }
    }
}
