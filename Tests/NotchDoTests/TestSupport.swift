import EventKit
import Foundation
@testable import NotchDo

enum TestFailure: Error {
    case requested
}

final class FakeReminderEventStore: ReminderEventStore {
    let backingStore = EKEventStore()

    var authorizationStatusStub: EKAuthorizationStatus = .fullAccess
    var accessGranted = true
    var accessError: Error?
    var calendarsStub: [EKCalendar] = []
    var defaultCalendarStub: EKCalendar?
    var fetchedReminders: [EKReminder]? = []
    var saveError: Error?
    var removeError: Error?
    var savedReminders: [EKReminder] = []
    var removedReminders: [EKReminder] = []
    var accessRequestCount = 0
    var fetchCount = 0

    var notificationObject: AnyObject? { self }

    func authorizationStatus() -> EKAuthorizationStatus {
        authorizationStatusStub
    }

    func requestFullAccessToReminders() async throws -> Bool {
        accessRequestCount += 1
        if let accessError {
            throw accessError
        }
        return accessGranted
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        calendarsStub
    }

    func defaultCalendarForNewReminders() -> EKCalendar? {
        defaultCalendarStub
    }

    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        NSPredicate(value: true)
    }

    func fetchReminders(
        matching predicate: NSPredicate,
        completion: @escaping ([EKReminder]?) -> Void
    ) -> Any {
        fetchCount += 1
        completion(fetchedReminders)
        return NSObject()
    }

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: backingStore)
    }

    func save(_ reminder: EKReminder, commit: Bool) throws {
        if let saveError {
            throw saveError
        }
        savedReminders.append(reminder)
        if fetchedReminders?.contains(where: {
            $0.calendarItemIdentifier == reminder.calendarItemIdentifier
        }) == false {
            fetchedReminders?.append(reminder)
        }
    }

    func remove(_ reminder: EKReminder, commit: Bool) throws {
        if let removeError {
            throw removeError
        }
        removedReminders.append(reminder)
        fetchedReminders?.removeAll {
            $0.calendarItemIdentifier == reminder.calendarItemIdentifier
        }
    }

    func makeCalendar(title: String) -> EKCalendar {
        let calendar = EKCalendar(for: .reminder, eventStore: backingStore)
        calendar.title = title
        return calendar
    }

    func makeReminder(
        title: String,
        calendar: EKCalendar,
        dueDateComponents: DateComponents? = nil,
        isCompleted: Bool = false
    ) -> EKReminder {
        let reminder = makeReminder()
        reminder.calendar = calendar
        reminder.title = title
        reminder.dueDateComponents = dueDateComponents
        reminder.isCompleted = isCompleted
        return reminder
    }
}

func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

func fixedDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0,
    minute: Int = 0
) -> Date {
    fixedCalendar().date(
        from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

func dueComponents(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int? = nil,
    minute: Int? = nil
) -> DateComponents {
    var components = DateComponents(
        calendar: fixedCalendar(),
        timeZone: hour == nil ? nil : TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day
    )
    components.hour = hour
    components.minute = minute
    return components
}
