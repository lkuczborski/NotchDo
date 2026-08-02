import EventKit
import Foundation
@testable import NotchDo

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
    var createdCalendars: [EKCalendar] = []
    var removedReminders: [EKReminder] = []
    var accessRequestCount = 0
    var fetchCount = 0
    var completesFetchImmediately = true
    var pendingFetchCompletions: [([EKReminder]?) -> Void] = []

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
        if completesFetchImmediately {
            completion(fetchedReminders)
        } else {
            pendingFetchCompletions.append(completion)
        }
        return NSObject()
    }

    func makeReminder() -> EKReminder {
        EKReminder(eventStore: backingStore)
    }

    func createReminderCalendar(title: String) throws -> EKCalendar {
        if let saveError {
            throw saveError
        }
        let calendar = makeCalendar(title: title)
        createdCalendars.append(calendar)
        calendarsStub.append(calendar)
        return calendar
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
