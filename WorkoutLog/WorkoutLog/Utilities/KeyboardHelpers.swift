import UIKit

/// Dismisses the keyboard from anywhere (used by the "Done" button above the number pad).
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
