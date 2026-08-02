import EventKit
import Testing
@testable import NotchDo

@Suite("Reminder draft")
struct ReminderDraftTests {
    @Test("Draft captures every editable reminder field")
    func capturesReminder() {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(
            title: "  Keep spacing  ",
            calendar: calendar,
            dueDateComponents: dueComponents(2026, 8, 3, hour: 14, minute: 25)
        )
        reminder.notes = "Notes"
        reminder.priority = 5
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        ]

        let draft = ReminderDraft(reminder: reminder)

        #expect(draft.title == "  Keep spacing  ")
        #expect(draft.notes == "Notes")
        #expect(draft.hasDueDate)
        #expect(draft.hasDueTime)
        #expect(draft.dueDate == fixedDate(2026, 8, 3, hour: 14, minute: 25))
        #expect(draft.priority == .medium)
        #expect(draft.recurrence == .weekly)
    }

    @Test("All-day and absent optional fields use safe defaults")
    func defaults() {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let allDay = events.makeReminder(
            title: "",
            calendar: calendar,
            dueDateComponents: dueComponents(2026, 8, 4)
        )
        allDay.title = nil
        allDay.notes = nil

        let allDayDraft = ReminderDraft(reminder: allDay)
        #expect(allDayDraft.title.isEmpty)
        #expect(allDayDraft.notes.isEmpty)
        #expect(allDayDraft.hasDueDate)
        #expect(!allDayDraft.hasDueTime)
        #expect(allDayDraft.dueDate == fixedDate(2026, 8, 4))
        #expect(allDayDraft.priority == .none)
        #expect(allDayDraft.recurrence == .never)

        let undated = events.makeReminder(title: "Later", calendar: calendar)
        let before = Date()
        let undatedDraft = ReminderDraft(reminder: undated)
        let after = Date()
        #expect(!undatedDraft.hasDueDate)
        #expect(!undatedDraft.hasDueTime)
        #expect(undatedDraft.dueDate >= before.addingTimeInterval(3599))
        #expect(undatedDraft.dueDate <= after.addingTimeInterval(3601))
    }

    @Test("Time requires Date and disabling Date also disables Time")
    func dueToggleInvariants() {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Call",
            calendar: events.makeCalendar(title: "Inbox")
        )
        var draft = ReminderDraft(reminder: reminder)

        draft.setDueTimeEnabled(true)
        #expect(draft.hasDueDate)
        #expect(draft.hasDueTime)
        #expect(draft.dueMode == .dateAndTime)

        draft.setDueDateEnabled(false)
        #expect(!draft.hasDueDate)
        #expect(!draft.hasDueTime)
        #expect(draft.dueMode == .none)

        draft.setDueDateEnabled(true)
        #expect(draft.hasDueDate)
        #expect(!draft.hasDueTime)
        #expect(draft.dueMode == .dateOnly)
    }
}
