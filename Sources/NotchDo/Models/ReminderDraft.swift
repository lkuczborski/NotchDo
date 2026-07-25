import EventKit
import Foundation

enum ReminderEditField: Hashable {
    case title
    case notes
    case dueDate
    case priority
    case recurrence
}

enum ReminderPriorityOption: Int, CaseIterable, Identifiable {
    case none = 0
    case low = 9
    case medium = 5
    case high = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    init(priority: Int) {
        switch priority {
        case 1...4: self = .high
        case 5: self = .medium
        case 6...9: self = .low
        default: self = .none
        }
    }
}

enum ReminderRecurrenceOption: String, CaseIterable, Identifiable {
    case never
    case daily
    case weekly
    case monthly
    case yearly
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    init(rules: [EKRecurrenceRule]?) {
        guard let rules, rules.count == 1, let rule = rules.first else {
            self = rules?.isEmpty == false ? .custom : .never
            return
        }

        switch rule.frequency {
        case .daily: self = .daily
        case .weekly: self = .weekly
        case .monthly: self = .monthly
        case .yearly: self = .yearly
        @unknown default: self = .custom
        }
    }

    var recurrenceRule: EKRecurrenceRule? {
        let frequency: EKRecurrenceFrequency
        switch self {
        case .never, .custom:
            return nil
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil)
    }
}

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
