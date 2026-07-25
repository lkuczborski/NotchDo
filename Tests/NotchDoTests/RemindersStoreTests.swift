import EventKit
import Testing
@testable import NotchDo

@Suite("Reminders store", .serialized)
@MainActor
struct RemindersStoreTests {
    @Test("Reload before authorization is a no-op")
    func unauthorizedReload() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        events.fetchedReminders = [
            events.makeReminder(title: "Hidden", calendar: inbox)
        ]
        let store = RemindersStore(eventStore: events)

        await store.reload()

        #expect(store.authorization == .notDetermined)
        #expect(store.reminders.isEmpty)
        #expect(store.syncState == .idle)
        #expect(events.fetchCount == 0)
    }

    @Test("Full access loads sorted calendars, selects the default, and reloads open reminders")
    func startWithFullAccess() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let errands = events.makeCalendar(title: "Errands")
        events.calendarsStub = [inbox, errands]
        events.defaultCalendarStub = inbox

        let later = events.makeReminder(
            title: "Later",
            calendar: inbox,
            dueDateComponents: dueComponents(2026, 8, 5)
        )
        let earlier = events.makeReminder(
            title: "Earlier",
            calendar: inbox,
            dueDateComponents: dueComponents(2026, 8, 4)
        )
        let alpha = events.makeReminder(title: "Alpha", calendar: inbox)
        let beta = events.makeReminder(title: "Beta", calendar: inbox)
        let completed = events.makeReminder(
            title: "Completed",
            calendar: inbox,
            isCompleted: true
        )
        events.fetchedReminders = [beta, completed, later, alpha, earlier]
        let syncDate = fixedDate(2026, 8, 3, hour: 10)
        let store = RemindersStore(eventStore: events, now: { syncDate })

        await store.start()

        #expect(store.authorization == .fullAccess)
        #expect(store.calendars.map(\.title) == ["Errands", "Inbox"])
        #expect(store.selectedCalendar === inbox)
        #expect(store.selectedCalendarIdentifier == inbox.calendarIdentifier)
        #expect(store.selectedCalendarTitle == "Inbox")
        #expect(store.reminders.map(\.title) == ["Earlier", "Later", "Alpha", "Beta"])
        #expect(store.lastSyncedAt == syncDate)
        #expect(store.syncState == .synced)
        #expect(events.fetchCount == 1)
    }

    @Test("Missing calendars leave a safe empty store")
    func noCalendars() async {
        let events = FakeReminderEventStore()
        events.fetchedReminders = [
            events.makeReminder(
                title: "Unreachable",
                calendar: events.makeCalendar(title: "Detached")
            )
        ]
        let store = RemindersStore(eventStore: events)

        await store.start()

        #expect(store.authorization == .fullAccess)
        #expect(store.calendars.isEmpty)
        #expect(store.selectedCalendar == nil)
        #expect(store.selectedCalendarTitle == "Reminders")
        #expect(store.reminders.isEmpty)
        #expect(store.syncState == .idle)
        #expect(events.fetchCount == 0)
        #expect(await !store.addReminder(title: "No destination"))
    }

    @Test("Calendar selection validates identifiers and survives EventKit refresh")
    func calendarSelectionAndRefresh() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let work = events.makeCalendar(title: "Work")
        events.calendarsStub = [work, inbox]
        events.defaultCalendarStub = inbox
        let store = RemindersStore(eventStore: events)
        await store.start()
        let fetchesAfterStart = events.fetchCount

        store.selectCalendar("missing")
        #expect(store.selectedCalendar === inbox)
        #expect(events.fetchCount == fetchesAfterStart)

        store.selectCalendar(work.calendarIdentifier)
        #expect(store.selectedCalendar === work)
        for _ in 0..<10 where events.fetchCount == fetchesAfterStart {
            await Task.yield()
        }
        #expect(events.fetchCount == fetchesAfterStart + 1)

        let personal = events.makeCalendar(title: "Personal")
        events.calendarsStub = [work, personal]
        NotificationCenter.default.post(
            name: .EKEventStoreChanged,
            object: events.notificationObject
        )
        for _ in 0..<10 where events.fetchCount < fetchesAfterStart + 2 {
            await Task.yield()
        }
        #expect(store.calendars.map(\.title) == ["Personal", "Work"])
        #expect(store.selectedCalendar === work)
        #expect(events.fetchCount == fetchesAfterStart + 2)
    }

    @Test(
        "Existing authorization statuses map without requesting access",
        arguments: [
            (EKAuthorizationStatus.notDetermined, ReminderAuthorizationState.notDetermined),
            (.restricted, .restricted),
            (.denied, .denied),
            (.writeOnly, .denied)
        ]
    )
    func authorizationMapping(
        status: EKAuthorizationStatus,
        expected: ReminderAuthorizationState
    ) async {
        let events = FakeReminderEventStore()
        events.authorizationStatusStub = status
        let store = RemindersStore(eventStore: events)

        await store.start()

        #expect(store.authorization == expected)
        #expect(events.accessRequestCount == 0)
        #expect(events.fetchCount == 0)
    }

    @Test("Access request handles granted, declined, and thrown results")
    func accessRequests() async {
        let grantedEvents = FakeReminderEventStore()
        grantedEvents.authorizationStatusStub = .notDetermined
        grantedEvents.calendarsStub = [grantedEvents.makeCalendar(title: "Inbox")]
        let grantedStore = RemindersStore(eventStore: grantedEvents)
        await grantedStore.requestAccess()
        #expect(grantedStore.authorization == .fullAccess)
        #expect(grantedEvents.accessRequestCount == 1)
        #expect(grantedEvents.fetchCount == 1)

        let declinedEvents = FakeReminderEventStore()
        declinedEvents.authorizationStatusStub = .notDetermined
        declinedEvents.accessGranted = false
        let declinedStore = RemindersStore(eventStore: declinedEvents)
        await declinedStore.requestAccess()
        #expect(declinedStore.authorization == .denied)
        #expect(declinedEvents.accessRequestCount == 1)

        let failingEvents = FakeReminderEventStore()
        failingEvents.authorizationStatusStub = .notDetermined
        failingEvents.accessError = TestFailure.requested
        let failingStore = RemindersStore(eventStore: failingEvents)
        await failingStore.requestAccess()
        #expect(failingStore.authorization == .denied)
        guard case .failed = failingStore.syncState else {
            Issue.record("An access error should become a failed sync state")
            return
        }
    }

    @Test("Reload treats a nil EventKit fetch result as an empty successful snapshot")
    func nilFetch() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        events.fetchedReminders = nil
        let store = RemindersStore(eventStore: events)

        await store.start()

        #expect(store.reminders.isEmpty)
        #expect(store.syncState == .synced)
        #expect(store.lastSyncedAt != nil)
    }

    @Test("Manual order survives reload and unseen reminders append in deterministic order")
    func preferredOrder() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let alpha = events.makeReminder(title: "Alpha", calendar: inbox)
        let beta = events.makeReminder(title: "Beta", calendar: inbox)
        let gamma = events.makeReminder(title: "Gamma", calendar: inbox)
        events.fetchedReminders = [gamma, alpha, beta]
        let store = RemindersStore(eventStore: events)
        await store.start()
        #expect(store.reminders.map(\.title) == ["Alpha", "Beta", "Gamma"])

        store.moveReminder(
            gamma.calendarItemIdentifier,
            relativeTo: alpha.calendarItemIdentifier,
            placeAfter: false
        )
        #expect(store.reminders.map(\.title) == ["Gamma", "Alpha", "Beta"])

        let aardvark = events.makeReminder(title: "Aardvark", calendar: inbox)
        let zebra = events.makeReminder(title: "Zebra", calendar: inbox)
        events.fetchedReminders = [zebra, beta, aardvark, alpha, gamma]
        await store.reload()
        #expect(store.reminders.map(\.title) == [
            "Gamma", "Alpha", "Beta", "Aardvark", "Zebra"
        ])
    }

    @Test("Invalid moves are no-ops; valid after-placement uses post-removal target index")
    func movingReminders() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let one = events.makeReminder(title: "One", calendar: inbox)
        let two = events.makeReminder(title: "Two", calendar: inbox)
        let three = events.makeReminder(title: "Three", calendar: inbox)
        events.fetchedReminders = [one, three, two]
        let store = RemindersStore(eventStore: events)
        await store.start()
        let original = store.reminders.map(\.calendarItemIdentifier)

        store.moveReminder("missing", relativeTo: two.calendarItemIdentifier, placeAfter: true)
        store.moveReminder(one.calendarItemIdentifier, relativeTo: "missing", placeAfter: true)
        store.moveReminder(one.calendarItemIdentifier, relativeTo: one.calendarItemIdentifier, placeAfter: true)
        #expect(store.reminders.map(\.calendarItemIdentifier) == original)

        store.moveReminder(
            one.calendarItemIdentifier,
            relativeTo: three.calendarItemIdentifier,
            placeAfter: true
        )
        #expect(store.reminders.map(\.title) == ["Three", "One", "Two"])
    }

    @Test("Adding trims titles, rejects empty input, and appends the new reminder")
    func addReminder() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let existing = events.makeReminder(title: "Existing", calendar: inbox)
        events.fetchedReminders = [existing]
        let store = RemindersStore(eventStore: events)
        await store.start()

        #expect(await !store.addReminder(title: " \n "))
        #expect(events.savedReminders.isEmpty)

        #expect(await store.addReminder(title: "  New task \n"))
        let added = events.savedReminders.last
        #expect(added?.title == "New task")
        #expect(added?.calendar === inbox)
        #expect(store.lastAddedReminderIdentifier == added?.calendarItemIdentifier)
        #expect(store.reminders.last === added)
    }

    @Test("Add failure is reported and does not claim a newly added identifier")
    func addFailure() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let store = RemindersStore(eventStore: events)
        await store.start()
        events.saveError = TestFailure.requested

        #expect(await !store.addReminder(title: "Will fail"))
        #expect(store.lastAddedReminderIdentifier == nil)
        guard case .failed = store.syncState else {
            Issue.record("A save error should become a failed sync state")
            return
        }
    }

    @Test("Completing is optimistic on success and fully rolls back on save failure")
    func completion() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let first = events.makeReminder(title: "First", calendar: inbox)
        let second = events.makeReminder(title: "Second", calendar: inbox)
        events.fetchedReminders = [first, second]
        let store = RemindersStore(eventStore: events)
        await store.start()

        events.saveError = TestFailure.requested
        await store.setCompleted(first)
        #expect(!first.isCompleted)
        #expect(store.reminders.contains { $0 === first })
        guard case .failed = store.syncState else {
            Issue.record("A completion save error should be surfaced")
            return
        }

        events.saveError = nil
        await store.setCompleted(first)
        #expect(first.isCompleted)
        #expect(!store.reminders.contains { $0 === first })
        #expect(events.savedReminders.last === first)
    }

    @Test("Rename trims valid titles, ignores empty titles, and restores on failure")
    func rename() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let reminder = events.makeReminder(title: "Original", calendar: inbox)
        events.fetchedReminders = [reminder]
        let store = RemindersStore(eventStore: events)
        await store.start()

        await store.rename(reminder, to: " \n ")
        #expect(reminder.title == "Original")
        #expect(events.savedReminders.isEmpty)

        await store.rename(reminder, to: "  Renamed  ")
        #expect(reminder.title == "Renamed")

        events.saveError = TestFailure.requested
        await store.rename(reminder, to: "Failed")
        #expect(reminder.title == "Renamed")
        guard case .failed = store.syncState else {
            Issue.record("A rename save error should be surfaced")
            return
        }
    }

    @Test("Update applies selected fields, preserves custom recurrence, and stamps sync time")
    func updateSelectedFields() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let reminder = events.makeReminder(title: "Original", calendar: inbox)
        let customRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 2,
            end: nil
        )
        reminder.notes = "Old notes"
        reminder.priority = 9
        reminder.recurrenceRules = [customRule]
        events.fetchedReminders = [reminder]
        let syncDate = fixedDate(2026, 8, 9, hour: 11)
        let store = RemindersStore(eventStore: events, now: { syncDate })
        await store.start()

        var draft = ReminderDraft(reminder: reminder)
        draft.title = "  Updated  "
        draft.notes = " \n "
        draft.hasDueDate = true
        draft.dueDate = fixedDate(2026, 9, 12, hour: 16, minute: 45)
        draft.isAllDay = false
        draft.priority = .high
        draft.recurrence = .custom

        await store.update(
            reminder,
            with: draft,
            fields: [.title, .notes, .dueDate, .priority, .recurrence]
        )

        #expect(reminder.title == "Updated")
        #expect(reminder.notes == nil)
        #expect(reminder.notchDueDate == draft.dueDate)
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = .autoupdatingCurrent
        let expectedTimedComponents = localCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: draft.dueDate
        )
        #expect(reminder.dueDateComponents?.hour == expectedTimedComponents.hour)
        #expect(reminder.dueDateComponents?.minute == expectedTimedComponents.minute)
        #expect(reminder.dueDateComponents?.timeZone != nil)
        #expect(reminder.priority == ReminderPriorityOption.high.rawValue)
        #expect(reminder.recurrenceRules?.first === customRule)
        #expect(store.lastSyncedAt == syncDate)
        #expect(store.syncState == .synced)
    }

    @Test("All-day update omits time; disabling due date and recurrence clears both")
    func dueDateAndRecurrenceClearing() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let reminder = events.makeReminder(
            title: "Original",
            calendar: inbox,
            dueDateComponents: dueComponents(2026, 8, 3, hour: 9, minute: 30)
        )
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        ]
        events.fetchedReminders = [reminder]
        let store = RemindersStore(eventStore: events)
        await store.start()

        var draft = ReminderDraft(reminder: reminder)
        draft.hasDueDate = true
        draft.dueDate = fixedDate(2026, 10, 2, hour: 22, minute: 10)
        draft.isAllDay = true
        draft.recurrence = .monthly
        await store.update(reminder, with: draft, fields: [.dueDate, .recurrence])
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = .autoupdatingCurrent
        let expectedAllDayComponents = localCalendar.dateComponents(
            [.year, .month, .day],
            from: draft.dueDate
        )
        #expect(reminder.dueDateComponents?.year == expectedAllDayComponents.year)
        #expect(reminder.dueDateComponents?.month == expectedAllDayComponents.month)
        #expect(reminder.dueDateComponents?.day == expectedAllDayComponents.day)
        #expect(reminder.dueDateComponents?.hour == nil)
        #expect(reminder.dueDateComponents?.timeZone == nil)
        #expect(reminder.recurrenceRules?.first?.frequency == .monthly)

        draft.hasDueDate = false
        draft.recurrence = .never
        await store.update(reminder, with: draft, fields: [.dueDate, .recurrence])
        #expect(reminder.dueDateComponents == nil)
        #expect(reminder.recurrenceRules?.isEmpty != false)
    }

    @Test("Blank title is excluded without blocking other fields; no effective fields do not save")
    func blankTitleFiltering() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let reminder = events.makeReminder(title: "Original", calendar: inbox)
        events.fetchedReminders = [reminder]
        let store = RemindersStore(eventStore: events)
        await store.start()

        var draft = ReminderDraft(reminder: reminder)
        draft.title = "  "
        await store.update(reminder, with: draft, fields: [.title])
        #expect(events.savedReminders.isEmpty)

        draft.notes = "Still saved"
        await store.update(reminder, with: draft, fields: [.title, .notes])
        #expect(reminder.title == "Original")
        #expect(reminder.notes == "Still saved")
        #expect(events.savedReminders.count == 1)
    }

    @Test("Update failure restores every mutated EventKit field")
    func updateRollback() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let originalDue = dueComponents(2026, 8, 3, hour: 9, minute: 15)
        let originalRule = EKRecurrenceRule(
            recurrenceWith: .yearly,
            interval: 1,
            end: nil
        )
        let reminder = events.makeReminder(
            title: "Original",
            calendar: inbox,
            dueDateComponents: originalDue
        )
        reminder.notes = "Original notes"
        reminder.priority = 5
        reminder.recurrenceRules = [originalRule]
        let originalDueDate = reminder.notchDueDate
        events.fetchedReminders = [reminder]
        let store = RemindersStore(eventStore: events)
        await store.start()
        events.saveError = TestFailure.requested

        var draft = ReminderDraft(reminder: reminder)
        draft.title = "Changed"
        draft.notes = "Changed notes"
        draft.hasDueDate = false
        draft.priority = .high
        draft.recurrence = .daily
        await store.update(
            reminder,
            with: draft,
            fields: [.title, .notes, .dueDate, .priority, .recurrence]
        )

        #expect(reminder.title == "Original")
        #expect(reminder.notes == "Original notes")
        #expect(reminder.notchDueDate == originalDueDate)
        #expect(reminder.priority == 5)
        #expect(reminder.recurrenceRules?.first === originalRule)
        guard case .failed = store.syncState else {
            Issue.record("An update save error should be surfaced")
            return
        }
    }

    @Test("Delete removes and reloads on success, but preserves data on failure")
    func delete() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let reminder = events.makeReminder(title: "Delete me", calendar: inbox)
        events.fetchedReminders = [reminder]
        let store = RemindersStore(eventStore: events)
        await store.start()

        events.removeError = TestFailure.requested
        await store.delete(reminder)
        #expect(store.reminders.contains { $0 === reminder })
        #expect(events.removedReminders.isEmpty)
        guard case .failed = store.syncState else {
            Issue.record("A remove error should be surfaced")
            return
        }

        events.removeError = nil
        await store.delete(reminder)
        #expect(store.reminders.isEmpty)
        #expect(events.removedReminders.last === reminder)
    }
}
