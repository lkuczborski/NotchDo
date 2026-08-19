import EventKit
import Observation

@MainActor
@Observable
final class ReminderDeletionConfirmation {
    private(set) var pendingReminder: EKReminder?

    func requestDeletion(of reminder: EKReminder) -> Bool {
        guard reminder.recurrenceRules?.isEmpty == false else { return true }
        pendingReminder = reminder
        return false
    }

    func confirmDeletion() -> EKReminder? {
        defer { pendingReminder = nil }
        return pendingReminder
    }

    func cancelDeletion() {
        pendingReminder = nil
    }

    func cancelIfReminderIsMissing(from identifiers: [String]) {
        guard let pendingReminder,
              !identifiers.contains(pendingReminder.calendarItemIdentifier) else { return }
        cancelDeletion()
    }
}
