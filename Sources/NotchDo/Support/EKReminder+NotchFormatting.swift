import EventKit
import Foundation

extension EKReminder {
    var notchDueDate: Date? {
        guard let components = dueDateComponents else { return nil }
        let calendar = components.calendar ?? Calendar.autoupdatingCurrent
        return calendar.date(from: components)
    }

    var notchDueMetadata: ReminderDueMetadata? {
        notchDueMetadata(relativeTo: Date(), calendar: .autoupdatingCurrent)
    }

    func notchDueMetadata(
        relativeTo now: Date,
        calendar: Calendar
    ) -> ReminderDueMetadata? {
        guard let dueDate = notchDueDate else { return nil }

        let includesTime = dueDateComponents?.hour != nil
        let dayText: String

        if calendar.isDate(dueDate, inSameDayAs: now) {
            dayText = "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            dayText = "Tomorrow"
        } else {
            dayText = dueDate.formatted(.dateTime.month(.abbreviated).day())
        }

        let text: String
        if includesTime {
            text = "\(dayText), \(dueDate.formatted(date: .omitted, time: .shortened))"
        } else {
            text = dayText
        }

        let overdueBoundary = includesTime ? now : calendar.startOfDay(for: now)
        return ReminderDueMetadata(text: text, isOverdue: dueDate < overdueBoundary)
    }

    var notchPrioritySymbol: String? {
        switch priority {
        case 1...4:
            return "!!!"
        case 5:
            return "!!"
        case 6...9:
            return "!"
        default:
            return nil
        }
    }
}
