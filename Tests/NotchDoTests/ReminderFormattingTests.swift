import EventKit
import Testing
@testable import NotchDo

@Suite("Reminder formatting")
struct ReminderFormattingTests {
    @Test("Convenience metadata uses the live clock and calendar")
    func convenienceMetadata() {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Today",
            calendar: events.makeCalendar(title: "Inbox")
        )
        let calendar = Calendar.autoupdatingCurrent
        reminder.dueDateComponents = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month, .day],
            from: Date()
        )

        #expect(reminder.notchDueMetadata?.text == "Today")
    }

    @Test("Missing and invalid due components produce no due date")
    func missingDueDate() {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "No date",
            calendar: events.makeCalendar(title: "Inbox")
        )
        #expect(reminder.notchDueDate == nil)
        #expect(
            reminder.notchDueMetadata(
                relativeTo: fixedDate(2026, 8, 3),
                calendar: fixedCalendar()
            ) == nil
        )
    }

    @Test("All-day metadata uses day boundaries for overdue state")
    func allDayBoundaries() throws {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(
            title: "Due today",
            calendar: calendar,
            dueDateComponents: dueComponents(2026, 8, 3)
        )
        let today = try #require(
            reminder.notchDueMetadata(
                relativeTo: fixedDate(2026, 8, 3, hour: 18),
                calendar: fixedCalendar()
            )
        )
        #expect(today.text == "Today")
        #expect(!today.isOverdue)

        let overdue = try #require(
            reminder.notchDueMetadata(
                relativeTo: fixedDate(2026, 8, 4, hour: 1),
                calendar: fixedCalendar()
            )
        )
        #expect(overdue.isOverdue)
    }

    @Test("Tomorrow and dated reminders use the intended labels")
    func dayLabels() throws {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Tomorrow",
            calendar: events.makeCalendar(title: "Inbox"),
            dueDateComponents: dueComponents(2026, 8, 4)
        )
        let tomorrow = try #require(
            reminder.notchDueMetadata(
                relativeTo: fixedDate(2026, 8, 3, hour: 12),
                calendar: fixedCalendar()
            )
        )
        #expect(tomorrow.text == "Tomorrow")

        reminder.dueDateComponents = dueComponents(2026, 9, 12)
        let dated = try #require(
            reminder.notchDueMetadata(
                relativeTo: fixedDate(2026, 8, 3),
                calendar: fixedCalendar()
            )
        )
        #expect(dated.text == fixedDate(2026, 9, 12).formatted(
            .dateTime.month(.abbreviated).day()
        ))
        #expect(!dated.isOverdue)
    }

    @Test("Timed reminders include time and become overdue at the exact instant")
    func timedBoundary() throws {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Meeting",
            calendar: events.makeCalendar(title: "Inbox"),
            dueDateComponents: dueComponents(2026, 8, 3, hour: 14, minute: 25)
        )
        let dueDate = fixedDate(2026, 8, 3, hour: 14, minute: 25)

        let atDueTime = try #require(
            reminder.notchDueMetadata(
                relativeTo: dueDate,
                calendar: fixedCalendar()
            )
        )
        #expect(atDueTime.text == "Today, \(dueDate.formatted(date: .omitted, time: .shortened))")
        #expect(!atDueTime.isOverdue)

        let afterDueTime = try #require(
            reminder.notchDueMetadata(
                relativeTo: dueDate.addingTimeInterval(1),
                calendar: fixedCalendar()
            )
        )
        #expect(afterDueTime.isOverdue)
    }

    @Test(
        "Priority symbols follow EventKit priority bands",
        arguments: [
            (0, nil),
            (1, "!!!"),
            (4, "!!!"),
            (5, "!!"),
            (6, "!"),
            (9, "!"),
            (10, nil)
        ] as [(Int, String?)]
    )
    func prioritySymbol(priority: Int, expected: String?) {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Priority",
            calendar: events.makeCalendar(title: "Inbox")
        )
        reminder.priority = priority
        #expect(reminder.notchPrioritySymbol == expected)
    }
}
