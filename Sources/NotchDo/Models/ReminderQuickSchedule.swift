import Foundation

enum ReminderQuickSchedule: CaseIterable, Identifiable {
    case today
    case tomorrow
    case nextWeek
    case clearDate

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next Week"
        case .clearDate: "Clear Date"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .tomorrow: "sunrise"
        case .nextWeek: "calendar.badge.plus"
        case .clearDate: "calendar.badge.minus"
        }
    }

    func apply(
        to draft: inout ReminderDraft,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        if self == .clearDate {
            draft.setDueDateEnabled(false)
            return
        }

        let dayOffset: Int
        switch self {
        case .today: dayOffset = 0
        case .tomorrow: dayOffset = 1
        case .nextWeek: dayOffset = 7
        case .clearDate: return
        }

        let startOfToday = calendar.startOfDay(for: now)
        guard let targetDay = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: startOfToday
        ) else { return }

        let scheduledDate: Date
        if draft.hasDueTime {
            let time = calendar.dateComponents([.hour, .minute], from: draft.dueDate)
            scheduledDate = calendar.date(
                bySettingHour: time.hour ?? 0,
                minute: time.minute ?? 0,
                second: 0,
                of: targetDay,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            ) ?? targetDay
        } else {
            scheduledDate = targetDay
        }

        draft.hasDueDate = true
        draft.dueDate = scheduledDate
    }
}
