import UIKit
import AudioToolbox

/// Haptic and sound feedback.
@MainActor
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Rest is over while the app is open: short friendly chime + vibration.
    /// (When the app is in the background, the scheduled notification plays its sound instead.)
    static func restFinished() {
        AudioServicesPlaySystemSound(1007)                  // short "tri-tone" chime
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) // vibrate
        success()
    }
}
