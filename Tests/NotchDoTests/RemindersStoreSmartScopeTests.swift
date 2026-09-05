import EventKit
import Foundation
import Testing
@testable import NotchDo

@Suite("Reminders store smart scopes", .serialized)
@MainActor
struct RemindersStoreSmartScopeTests {
    @Test("A real list remains the launch default and smart scopes project all source calendars in EventKit order")
    func selectionAndProjection() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let work = events.makeCalendar(title: "Work")
        let today = events.makeReminder(
            title: "Today",
            calendar: work,
            dueDateComponents: dueComponents(2026, 8, 24)
        )
        let undated = events.makeReminder(title: "Undated", calendar: inbox)
        let completed = events.makeReminder(
            title: "Done",
            calendar: work,
            dueDateComponents: dueComponents(2026, 8, 24),
            isCompleted: true
        )
        events.calendarsStub = [inbox, work]
        events.defaultCalendarStub = inbox
        events.fetchedReminders = [undated, today, completed]
        let store = RemindersStore(
            eventStore: events,
            now: { fixedDate(2026, 8, 24, hour: 12) },
            calendar: fixedCalendar()
        )

        await store.start()
        #expect(store.selectedSmartScope == nil)
        #expect(store.selectedCalendar === inbox)

        store.selectSmartScope(.today)
        await waitForFetch(events, count: 2)
        #expect(store.selectedCalendarTitle == "Today")
        #expect(store.reminders.count == 1)
        #expect(store.reminders.first === today)
        #expect(Set(events.predicateCalendarIdentifiers.last ?? []) == Set([
            inbox.calendarIdentifier,
            work.calendarIdentifier
        ]))

        store.selectSmartScope(.allOpen)
        await waitForFetch(events, count: 3)
        #expect(store.reminders.map(\.title) == ["Undated", "Today"])

        store.selectCalendar(work.calendarIdentifier)
        await waitForFetch(events, count: 4)
        #expect(store.selectedSmartScope == nil)
        #expect(store.selectedCalendar === work)
        #expect(events.predicateCalendarIdentifiers.last == [work.calendarIdentifier])
    }

    @Test("Smart-scope mutations target original reminders and respect each source calendar")
    func mutationsAndReadOnlySources() async {
        let events = FakeReminderEventStore()
        let shared = events.makeCalendar(title: "Shared")
        let personal = events.makeCalendar(title: "Personal")
        let blocked = events.makeReminder(title: "Blocked", calendar: shared)
        let editable = events.makeReminder(title: "Editable", calendar: personal)
        events.calendarsStub = [shared, personal]
        events.defaultCalendarStub = personal
        events.fetchedReminders = [blocked, editable]
        events.readOnlyCalendarIdentifiers = [shared.calendarIdentifier]
        let store = RemindersStore(eventStore: events)
        await store.start()
        store.selectSmartScope(.allOpen)
        await waitForFetch(events, count: 2)

        #expect(!store.selectedCalendarIsWritable)
        #expect(!store.canModify(blocked))
        #expect(store.canModify(editable))
        #expect(!(await store.setCompleted(blocked)))
        #expect(await store.setCompleted(editable))
        #expect(events.savedReminders.count == 1)
        #expect(events.savedReminders.first === editable)
        #expect(store.reminders.count == 1)
        #expect(store.reminders.first === blocked)
    }

    @Test("A stale smart-scope fetch cannot overwrite the newest selection")
    func staleReloadAfterScopeSelection() async throws {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let today = events.makeReminder(
            title: "Today",
            calendar: inbox,
            dueDateComponents: dueComponents(2026, 8, 24)
        )
        let overdue = events.makeReminder(
            title: "Overdue",
            calendar: inbox,
            dueDateComponents: dueComponents(2026, 8, 23)
        )
        events.calendarsStub = [inbox]
        events.fetchedReminders = []
        let store = RemindersStore(
            eventStore: events,
            now: { fixedDate(2026, 8, 24, hour: 12) },
            calendar: fixedCalendar()
        )
        await store.start()
        events.completesFetchImmediately = false

        store.selectSmartScope(.today)
        await waitForPendingFetches(events, count: 1)
        store.selectSmartScope(.overdue)
        await waitForPendingFetches(events, count: 2)

        let todayCompletion = try #require(events.pendingFetchCompletions.first)
        let overdueCompletion = try #require(events.pendingFetchCompletions.dropFirst().first)
        overdueCompletion([today, overdue])
        for _ in 0..<20 where store.reminders.first !== overdue {
            await Task.yield()
        }
        todayCompletion([today])
        await Task.yield()

        #expect(store.selectedSmartScope == .overdue)
        #expect(store.reminders.count == 1)
        #expect(store.reminders.first === overdue)
    }

    @Test("External EventKit changes refresh the active projection")
    func externalChanges() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let first = events.makeReminder(title: "First", calendar: inbox)
        events.calendarsStub = [inbox]
        events.fetchedReminders = [first]
        let store = RemindersStore(eventStore: events)
        await store.start()
        store.selectSmartScope(.allOpen)
        await waitForFetch(events, count: 2)

        let external = events.makeReminder(title: "External", calendar: inbox)
        events.fetchedReminders = [external, first]
        NotificationCenter.default.post(
            name: .EKEventStoreChanged,
            object: events.notificationObject
        )
        await waitForFetch(events, count: 3)

        #expect(store.selectedSmartScope == .allOpen)
        #expect(store.reminders.map(\.title) == ["External", "First"])
    }

    private func waitForFetch(_ events: FakeReminderEventStore, count: Int) async {
        for _ in 0..<20 where events.fetchCount < count {
            await Task.yield()
        }
    }

    private func waitForPendingFetches(_ events: FakeReminderEventStore, count: Int) async {
        for _ in 0..<20 where events.pendingFetchCompletions.count < count {
            await Task.yield()
        }
    }
}
