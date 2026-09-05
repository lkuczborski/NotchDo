#if NOTCHDO_DEMO
import AppKit
import EventKit

/// Recording fixtures only. The backing store constructs unsaved model objects;
/// no authorization, fetch, save, calendar, or source APIs are called on it.
/// The live EKEventStore protocol conformance is excluded from this build.
final class DemoReminderEventStore: ReminderEventStore {
    private let modelFactory = EKEventStore()
    private var lists: [EKCalendar] = []
    private var items: [EKReminder] = []
    private var readOnlyIDs: Set<String> = []
    private var status: EKAuthorizationStatus
    var notificationObject: AnyObject? { self }

    init(scenario: String = "features", now: Date = Date(), calendar: Calendar = .current) {
        precondition(["features", "first-list", "permission"].contains(scenario), "Unknown demo scenario")
        status = scenario == "permission" ? .notDetermined : .fullAccess
        guard scenario == "features" else { return }
        let studio = try! createReminderCalendar(title: "Studio")
        studio.cgColor = NSColor.systemPurple.cgColor
        let personal = try! createReminderCalendar(title: "Weekend")
        personal.cgColor = NSColor.systemOrange.cgColor
        let reference = try! createReminderCalendar(title: "Shared inspiration")
        reference.cgColor = NSColor.systemBlue.cgColor
        _ = try! createReminderCalendar(title: "Someday")
        readOnlyIDs.insert(reference.calendarIdentifier)
        let fixtures: [(String, EKCalendar, Int?)] = [
            ("Sketch the autumn collection", studio, 0),
            ("Review café moodboard", studio, 0),
            ("Send sample palette", studio, -1),
            ("Photograph paper prototypes", studio, 3),
            ("Explore packaging ideas", studio, nil),
            ("Refine the launch checklist", studio, 7),
            ("Choose a display typeface", studio, nil),
            ("Plan the studio open day", studio, 10),
            ("Pick up fresh flowers", personal, 0),
            ("Book the ceramics workshop", personal, 4),
            ("Return library books", personal, -2),
            ("Visit the design exhibition", reference, 2)
        ]
        for (title, list, offset) in fixtures {
            let item = makeReminder()
            item.title = title
            item.calendar = list
            if let offset {
                item.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: offset, to: now)!)
            }
            items.append(item)
        }
        items[0].notes = "Explore warm colors and playful shapes."
        items[0].priority = 1
    }

    func authorizationStatus() -> EKAuthorizationStatus { status }
    func requestFullAccessToReminders() async throws -> Bool {
        status = .fullAccess
        return true
    }
    func calendars(for entityType: EKEntityType) -> [EKCalendar] { lists }
    func allowsContentModifications(in calendar: EKCalendar) -> Bool {
        !readOnlyIDs.contains(calendar.calendarIdentifier)
    }
    func defaultCalendarForNewReminders() -> EKCalendar? {
        lists.first { allowsContentModifications(in: $0) }
    }
    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        let identifiers = Set((calendars ?? lists).map(\.calendarIdentifier))
        return NSPredicate { object, _ in
            guard let reminder = object as? EKReminder else { return false }
            return identifiers.contains(reminder.calendar.calendarIdentifier)
        }
    }
    func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(items.filter { predicate.evaluate(with: $0) })
        return NSObject()
    }
    func makeReminder() -> EKReminder { EKReminder(eventStore: modelFactory) }
    func createReminderCalendar(title: String) throws -> EKCalendar {
        let list = EKCalendar(for: .reminder, eventStore: modelFactory)
        list.title = title
        lists.append(list)
        return list
    }
    func save(_ reminder: EKReminder, commit: Bool) throws {
        guard allowsContentModifications(in: reminder.calendar) else { throw CocoaError(.fileWriteNoPermission) }
        if !items.contains(where: { $0 === reminder }) { items.append(reminder) }
    }
    func remove(_ reminder: EKReminder, commit: Bool) throws {
        guard allowsContentModifications(in: reminder.calendar) else { throw CocoaError(.fileWriteNoPermission) }
        items.removeAll { $0 === reminder }
    }
}
#endif
