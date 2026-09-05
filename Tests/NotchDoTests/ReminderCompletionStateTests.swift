import EventKit
import Testing
@testable import NotchDo

@Suite("Retained reminder completion state", .serialized)
@MainActor
struct ReminderCompletionStateTests {
    @Test("Complete, undo and complete again preserves identity, fields and order",
          arguments: [nil, .today, .overdue, .scheduled, .allOpen] as [ReminderSmartScope?])
    func completeUndoComplete(scope: ReminderSmartScope?) async throws {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let source = scope == nil ? inbox : events.makeCalendar(title: "Source")
        let due = dueComponents(2026, 8, scope == .overdue ? 23 : 24)
        let reminder = events.makeReminder(title: "Flowers", calendar: source, dueDateComponents: due)
        reminder.notes = "Preserve notes"
        reminder.url = URL(string: "https://example.com/flowers")
        reminder.priority = 5
        let neighbor = events.makeReminder(title: "Neighbor", calendar: source, dueDateComponents: due)
        events.calendarsStub = scope == nil ? [inbox] : [inbox, source]
        events.defaultCalendarStub = inbox
        events.fetchedReminders = [neighbor, reminder]
        let sleeper = CompletionUndoTestSleeper()
        defer { sleeper.resumeAll() }
        let store = RemindersStore(
            eventStore: events,
            now: { fixedDate(2026, 8, 24, hour: 12) },
            calendar: fixedCalendar(),
            completionUndoSleep: { await sleeper.sleep(for: $0) }
        )
        await store.start()
        if let scope {
            store.selectSmartScope(scope)
            await store.reload()
        }
        // Keep exactly the same interaction state, as a retained SwiftUI row does.
        let row = ReminderCompletionState()
        #expect(await row.complete(isEditable: store.canModify(reminder), sleep: {}) {
            await store.setCompleted(reminder)
        })
        #expect(!row.isCompleting)
        #expect(reminder.isCompleted)
        #expect(store.reminders.count == 1)
        #expect(await store.undoRecentCompletion())
        #expect(!reminder.isCompleted)
        #expect(store.reminders.map(\.calendarItemIdentifier) == [neighbor, reminder].map(\.calendarItemIdentifier))
        #expect(store.reminders.last === reminder)
        #expect(reminder.calendar === source)
        #expect(reminder.notes == "Preserve notes")
        #expect(reminder.url?.absoluteString == "https://example.com/flowers")
        #expect(reminder.priority == 5)
        #expect(reminder.dueDateComponents == due)
        #expect(await row.complete(isEditable: store.canModify(reminder), sleep: {}) {
            await store.setCompleted(reminder)
        })
        #expect(!row.isCompleting)
        #expect(reminder.isCompleted)
        #expect(store.reminders.count == 1)
        #expect(events.savedReminders.count == 3)
        #expect(events.savedReminders.allSatisfy { $0 === reminder })
        store.dismissCompletionUndo()
    }

    @Test("Failure releases feedback and preserves retry; read-only and duplicate attempts do not save")
    func failureAndGuards() async {
        let row = ReminderCompletionState()
        var saves = 0
        #expect(!(await row.complete(isEditable: false, sleep: {}) { saves += 1; return true }))
        let failed = await row.complete(isEditable: true, sleep: {}) {
            #expect(row.isCompleting)
            #expect(!(await row.complete(isEditable: true, sleep: {}) { saves += 1; return true }))
            saves += 1
            return false
        }
        #expect(!failed)
        #expect(!row.isCompleting)
        #expect(await row.complete(isEditable: true, sleep: {}) { saves += 1; return true })
        #expect(saves == 2)
        #expect(!row.isCompleting)
    }

    @Test("Cancelled feedback delay releases the row without saving")
    func cancelledDelay() async {
        let row = ReminderCompletionState()
        var saved = false
        #expect(!(await row.complete(isEditable: true, sleep: { throw CancellationError() }) {
            saved = true
            return true
        }))
        #expect(!saved)
        #expect(!row.isCompleting)
    }
}
