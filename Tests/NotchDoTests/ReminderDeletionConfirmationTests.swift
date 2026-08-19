import EventKit
import Testing
@testable import NotchDo

@MainActor
@Suite("Reminder deletion confirmation")
struct ReminderDeletionConfirmationTests {
    @Test("Non-repeating reminders can be deleted immediately")
    func nonRepeatingReminder() {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "One time",
            calendar: events.makeCalendar(title: "Inbox")
        )
        let confirmation = ReminderDeletionConfirmation()

        #expect(confirmation.requestDeletion(of: reminder))
        #expect(confirmation.pendingReminder == nil)
    }

    @Test("Repeating reminders wait for explicit confirmation")
    func repeatingReminder() {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Repeat",
            calendar: events.makeCalendar(title: "Inbox")
        )
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        ]
        let confirmation = ReminderDeletionConfirmation()

        #expect(!confirmation.requestDeletion(of: reminder))
        #expect(confirmation.pendingReminder === reminder)
        #expect(confirmation.confirmDeletion() === reminder)
        #expect(confirmation.pendingReminder == nil)
    }

    @Test("Cancelling preserves the repeating reminder")
    func cancellation() {
        let events = FakeReminderEventStore()
        let reminder = events.makeReminder(
            title: "Keep repeating",
            calendar: events.makeCalendar(title: "Inbox")
        )
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        ]
        let confirmation = ReminderDeletionConfirmation()

        #expect(!confirmation.requestDeletion(of: reminder))
        confirmation.cancelDeletion()

        #expect(confirmation.pendingReminder == nil)
        #expect(confirmation.confirmDeletion() == nil)
    }
}
