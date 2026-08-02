import AppKit
import SwiftUI

/// A narrow AppKit bridge used because SwiftUI's graphical `DatePicker`
/// always draws a blue focus frame on macOS. SwiftUI remains the source of
/// truth for the selected date.
struct FocuslessGraphicalDatePicker: NSViewRepresentable {
    @Binding var selection: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> FocuslessDatePicker {
        let picker = FocuslessDatePicker()
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerMode = .single
        picker.isBordered = false
        picker.focusRingType = .none
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.valueChanged(_:))
        update(picker)
        return picker
    }

    func updateNSView(_ picker: FocuslessDatePicker, context: Context) {
        context.coordinator.parent = self
        update(picker)
    }

    private func update(_ picker: FocuslessDatePicker) {
        if picker.dateValue != selection {
            picker.dateValue = selection
        }
        picker.datePickerElements = [.yearMonthDay]
        picker.setAccessibilityLabel("Due date")
    }

    final class Coordinator: NSObject {
        var parent: FocuslessGraphicalDatePicker

        init(parent: FocuslessGraphicalDatePicker) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSDatePicker) {
            parent.selection = sender.dateValue
        }
    }
}

final class FocuslessDatePicker: NSDatePicker {
    override var focusRingMaskBounds: NSRect { .zero }

    override func drawFocusRingMask() {}
}
