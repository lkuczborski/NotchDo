import EventKit
import Foundation
import Testing
@testable import NotchDo

@Suite("Reminder quick scheduling", .serialized)
@MainActor
struct ReminderQuickScheduleTests {
    @Test("Calendar-day shortcuts cross year boundaries in the selected time zone")
    func calendarDayBoundaries() {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(title: "Plan", calendar: calendar)
        let timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone
        let now = localCalendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: 2026,
                month: 12,
                day: 31,
                hour: 23,
                minute: 45
            )
        )!

        let expectations: [(ReminderQuickSchedule, DateComponents)] = [
            (.today, DateComponents(year: 2026, month: 12, day: 31)),
            (.tomorrow, DateComponents(year: 2027, month: 1, day: 1)),
            (.nextWeek, DateComponents(year: 2027, month: 1, day: 7))
        ]

        for (shortcut, expected) in expectations {
            var draft = ReminderDraft(reminder: reminder)
            shortcut.apply(to: &draft, now: now, calendar: localCalendar)
            let actual = localCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: draft.dueDate
            )

            #expect(draft.hasDueDate)
            #expect(!draft.hasDueTime)
            #expect(actual.year == expected.year)
            #expect(actual.month == expected.month)
            #expect(actual.day == expected.day)
            #expect(actual.hour == 0)
            #expect(actual.minute == 0)
        }
    }

    @Test("Scheduling preserves an existing due time across daylight-saving changes")
    func preservesTimeAcrossDST() {
        let events = FakeReminderEventStore()
        let reminderCalendar = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(
            title: "Call",
            calendar: reminderCalendar,
            dueDateComponents: dueComponents(2026, 4, 2, hour: 9, minute: 45)
        )
        var draft = ReminderDraft(reminder: reminder, dueMode: .dateAndTime)
        let timeZone = TimeZone(identifier: "Europe/Warsaw")!
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone
        draft.dueDate = localCalendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: 2026,
                month: 3,
                day: 28,
                hour: 9,
                minute: 45
            )
        )!
        let now = localCalendar.date(
            from: DateComponents(
                timeZone: timeZone,
                year: 2026,
                month: 3,
                day: 28,
                hour: 23,
                minute: 30
            )
        )!

        let shortcut = ReminderQuickSchedule.tomorrow
        shortcut.apply(to: &draft, now: now, calendar: localCalendar)
        let components = localCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: draft.dueDate
        )

        #expect(draft.dueMode == .dateAndTime)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 29)
        #expect(components.hour == 9)
        #expect(components.minute == 45)
    }

    @Test("Clear Date removes date and time together")
    func clearDate() {
        let events = FakeReminderEventStore()
        let reminderCalendar = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(
            title: "Call",
            calendar: reminderCalendar,
            dueDateComponents: dueComponents(2026, 8, 19, hour: 16, minute: 30)
        )
        var draft = ReminderDraft(reminder: reminder, dueMode: .dateAndTime)

        let shortcut = ReminderQuickSchedule.clearDate
        shortcut.apply(to: &draft, now: fixedDate(2026, 8, 19), calendar: fixedCalendar())

        #expect(draft.dueMode == .none)
        #expect(!draft.hasDueDate)
        #expect(!draft.hasDueTime)
    }

    @Test("A failed quick-schedule save restores the EventKit due date")
    func updateFailureRollsBack() async {
        let events = FakeReminderEventStore()
        let reminderCalendar = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [reminderCalendar]
        let originalComponents = dueComponents(2026, 8, 19, hour: 16, minute: 30)
        let reminder = events.makeReminder(
            title: "Call",
            calendar: reminderCalendar,
            dueDateComponents: originalComponents
        )
        let originalDueDate = reminder.notchDueDate
        events.fetchedReminders = [reminder]
        let store = RemindersStore(eventStore: events)
        await store.start()
        events.saveError = TestFailure.requested

        var draft = ReminderDraft(reminder: reminder, dueMode: .dateAndTime)
        let shortcut = ReminderQuickSchedule.tomorrow
        shortcut.apply(
            to: &draft,
            now: fixedDate(2026, 8, 19, hour: 23),
            calendar: fixedCalendar()
        )
        let result = await store.update(reminder, with: draft, fields: [.dueDate])

        #expect(!result.succeeded)
        #expect(reminder.notchDueDate == originalDueDate)
        #expect(ReminderDueMode(components: reminder.dueDateComponents) == .dateAndTime)
        guard case .failed = store.syncState else {
            Issue.record("The quick-schedule save error should be visible")
            return
        }
    }
}
