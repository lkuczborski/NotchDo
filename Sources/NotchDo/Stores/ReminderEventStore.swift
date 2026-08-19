import EventKit
import Foundation

protocol ReminderEventStore: AnyObject {
    var notificationObject: AnyObject? { get }

    func authorizationStatus() -> EKAuthorizationStatus
    func requestFullAccessToReminders() async throws -> Bool
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func allowsContentModifications(in calendar: EKCalendar) -> Bool
    func defaultCalendarForNewReminders() -> EKCalendar?
    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
    func fetchReminders(
        matching predicate: NSPredicate,
        completion: @escaping ([EKReminder]?) -> Void
    ) -> Any
    func makeReminder() -> EKReminder
    func createReminderCalendar(title: String) throws -> EKCalendar
    func save(_ reminder: EKReminder, commit: Bool) throws
    func remove(_ reminder: EKReminder, commit: Bool) throws
}
