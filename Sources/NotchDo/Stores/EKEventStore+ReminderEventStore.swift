import EventKit

extension EKEventStore: ReminderEventStore {
    var notificationObject: AnyObject? { self }

    func authorizationStatus() -> EKAuthorizationStatus {
        Self.authorizationStatus(for: .reminder)
    }

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: self)
    }
}
