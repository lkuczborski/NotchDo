import SwiftUI

/// Uses the native field-style time picker so hours and minutes remain
/// keyboard-editable while macOS owns parsing, range validation, and locale.
struct ValidatingTimeField: View {
    @Binding var selection: Date

    var body: some View {
        DatePicker(
            "Time",
            selection: $selection,
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.field)
        .controlSize(.small)
        .fixedSize()
        // The native time glyphs sit slightly high relative to our date field.
        .offset(y: 1)
        .frame(width: 58, height: 22)
        .background(
            .white.opacity(0.075),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("Due time")
        .accessibilityHint("Enter a valid hour and minute")
    }
}
