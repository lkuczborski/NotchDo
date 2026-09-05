import Foundation

struct QuickCaptureState: Equatable {
    var title = ""
    var notes = ""
    var includesDueDate = false
    var dueDate: Date
    var calendarIdentifier: String?

    init(
        now: Date = Date(),
        calendarIdentifier: String? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        dueDate = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        self.calendarIdentifier = calendarIdentifier
    }

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var reminderDraft: ReminderDraft {
        var draft = ReminderDraft(
            title: title,
            notes: notes,
            dueDate: includesDueDate ? dueDate : nil
        )
        draft.hasDueTime = false
        return draft
    }

    mutating func reset(
        now: Date = Date(),
        selectedCalendarIdentifier: String?,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self = QuickCaptureState(
            now: now,
            calendarIdentifier: selectedCalendarIdentifier,
            calendar: calendar
        )
    }
}
