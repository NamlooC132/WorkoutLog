import Foundation
import UserNotifications

/// Schedules the "rest is over" local notification.
///
/// This is what makes the rest timer work while the phone is locked or the app is
/// in the background: iOS delivers the notification (with sound) at the right time
/// even if the app is suspended.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let restTimerID = "rest-timer"

    /// Call once at launch.
    func configure() {
        center.delegate = self
    }

    /// Asks for permission the first time only (called when a workout starts).
    func requestPermissionIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces any pending rest notification with one firing in `seconds`.
    func scheduleRestNotification(in seconds: TimeInterval, exerciseName: String) {
        center.removePendingNotificationRequests(withIdentifiers: [restTimerID])
        guard seconds >= 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest is over 💪"
        content.body = exerciseName.isEmpty
            ? "Time for your next set."
            : "Time for your next set of \(exerciseName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: restTimerID, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelRestNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [restTimerID])
        center.removeDeliveredNotifications(withIdentifiers: [restTimerID])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// App is open: the in-app timer already plays a chime, so don't show a duplicate banner.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == "rest-timer" {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
