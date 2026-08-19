import EventKit

extension EKEventStore: ReminderEventStore {
    var notificationObject: AnyObject? { self }

    func authorizationStatus() -> EKAuthorizationStatus {
        Self.authorizationStatus(for: .reminder)
    }

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: self)
    }

    func allowsContentModifications(in calendar: EKCalendar) -> Bool {
        calendar.allowsContentModifications
    }

    func createReminderCalendar(title: String) throws -> EKCalendar {
        let calendar = EKCalendar(for: .reminder, eventStore: self)
        let source = defaultCalendarForNewReminders()?.source
            ?? calendars(for: .reminder)
                .first(where: { $0.allowsContentModifications })?.source
            ?? sources.first(where: { source in
                switch source.sourceType {
                case .calDAV, .local, .exchange, .mobileMe:
                    true
                case .subscribed, .birthdays:
                    false
                @unknown default:
                    false
                }
            })

        guard let source else {
            throw NSError(
                domain: "NotchDo.EventKit",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No writable Reminders account is available for a new list."
                ]
            )
        }

        calendar.title = title
        calendar.source = source
        try saveCalendar(calendar, commit: true)
        return calendar
    }
}
