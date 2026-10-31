import SwiftUI
import Combine

/// A big, easy-to-tap number box that opens the numeric keypad.
///
/// It keeps its own text while you type (so "62." isn't reformatted mid-entry) and
/// writes every change straight to the bound value, so nothing is lost if you tap
/// the checkmark without closing the keyboard first.
struct NumberInputField: View {
    @Binding var value: Double
    var allowsDecimal: Bool = true
    var placeholder: String = "0"
    var font: Font = .title3.weight(.semibold)
    var minHeight: CGFloat = 48

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(value: Binding<Double>, allowsDecimal: Bool = true, placeholder: String = "0",
         font: Font = .title3.weight(.semibold), minHeight: CGFloat = 48) {
        self._value = value
        self.allowsDecimal = allowsDecimal
        self.placeholder = placeholder
        self.font = font
        self.minHeight = minHeight
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(font.monospacedDigit())
            .focused($isFocused)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2)
            )
            .onAppear { text = format(value) }
            .onChange(of: text) { _, newText in
                let parsed = Fmt.parseNumber(newText) ?? 0
                let clean = allowsDecimal ? max(0, parsed) : max(0, parsed.rounded())
                if abs(clean - value) > 0.0001 { value = clean }
            }
            .onChange(of: value) { _, newValue in
                // Value changed from outside (e.g. −/+ buttons or "Apply"): refresh the text.
                let shown = Fmt.parseNumber(text) ?? 0
                if abs(shown - newValue) > 0.0001 { text = format(newValue) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = format(value) } // tidy up e.g. "62." → "62"
            }
            // Select the whole number when the field is tapped, so typing replaces it
            // (no need to delete the prefilled value first).
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                guard let field = note.object as? UITextField else { return }
                Task { @MainActor in field.selectAll(nil) }
            }
    }

    /// 0 shows as empty so the placeholder is visible and typing starts fresh.
    private func format(_ number: Double) -> String {
        guard number > 0 else { return "" }
        return allowsDecimal ? Fmt.number(number) : String(Int(number.rounded()))
    }
}
