import Foundation

struct ReminderSmartScopeMembership: Sendable {
    let now: Date
    let calendar: Calendar

    func contains(
        isCompleted: Bool,
        dueDateComponents: DateComponents?,
        in scope: ReminderSmartScope
    ) -> Bool {
        guard !isCompleted else { return false }

        switch scope {
        case .allOpen:
            return true
        case .scheduled:
            return dueDateComponents != nil
        case .today:
            guard let dueDate = resolvedDueDate(from: dueDateComponents) else { return false }
            return calendar.isDate(dueDate, inSameDayAs: now)
        case .overdue:
            guard let components = dueDateComponents,
                  let dueDate = resolvedDueDate(from: components) else { return false }
            if isAllDay(components) {
                return dueDate < calendar.startOfDay(for: now)
            }
            return dueDate < now
        }
    }

    private func resolvedDueDate(from components: DateComponents?) -> Date? {
        guard let components else { return nil }
        var resolver = components.calendar ?? calendar
        resolver.timeZone = components.timeZone ?? calendar.timeZone
        return resolver.date(from: components)
    }

    private func isAllDay(_ components: DateComponents) -> Bool {
        components.hour == nil
            && components.minute == nil
            && components.second == nil
            && components.nanosecond == nil
    }
}
