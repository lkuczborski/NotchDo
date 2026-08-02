import EventKit
import Foundation

struct ReminderDraft: Equatable {
    var title: String
    var notes: String
    var hasDueDate: Bool
    var hasDueTime: Bool
    var dueDate: Date
    var priority: ReminderPriorityOption
    var recurrence: ReminderRecurrenceOption

    init(reminder: EKReminder, dueMode: ReminderDueMode? = nil) {
        title = reminder.title ?? ""
        notes = reminder.notes ?? ""
        let components = reminder.dueDateComponents
        let resolvedDueMode = dueMode ?? ReminderDueMode(components: components)
        hasDueDate = resolvedDueMode.hasDate
        hasDueTime = resolvedDueMode.hasTime
        dueDate = reminder.notchDueDate
            ?? Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: Date())
            ?? Date()
        priority = ReminderPriorityOption(priority: reminder.priority)
        recurrence = ReminderRecurrenceOption(rules: reminder.recurrenceRules)
    }

    var dueMode: ReminderDueMode {
        switch (hasDueDate, hasDueTime) {
        case (true, true): .dateAndTime
        case (true, false): .dateOnly
        case (false, true): .dateAndTime
        case (false, false): .none
        }
    }

    mutating func setDueDateEnabled(_ enabled: Bool) {
        hasDueDate = enabled
        if !enabled {
            hasDueTime = false
        }
    }

    mutating func setDueTimeEnabled(_ enabled: Bool) {
        hasDueTime = enabled
        if enabled {
            hasDueDate = true
        }
    }
}
