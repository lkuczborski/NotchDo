import EventKit
import Foundation

struct ReminderDraft: Equatable {
    var title: String
    var notes: String
    var hasDueDate: Bool
    var dueDate: Date
    var isAllDay: Bool
    var priority: ReminderPriorityOption
    var recurrence: ReminderRecurrenceOption

    init(reminder: EKReminder) {
        title = reminder.title ?? ""
        notes = reminder.notes ?? ""
        hasDueDate = reminder.dueDateComponents != nil
        dueDate = reminder.notchDueDate
            ?? Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: Date())
            ?? Date()
        isAllDay = reminder.dueDateComponents?.hour == nil
        priority = ReminderPriorityOption(priority: reminder.priority)
        recurrence = ReminderRecurrenceOption(rules: reminder.recurrenceRules)
    }
}
