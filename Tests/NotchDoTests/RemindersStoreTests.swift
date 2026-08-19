import EventKit
import Foundation
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

    @Test("Full access loads sorted calendars, selects the default, and preserves reminder order")
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
        #expect(store.reminders.map(\.title) == ["Beta", "Later", "Alpha", "Earlier"])
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

    @Test("The last selected calendar is restored by a new store")
    func calendarSelectionPersistence() async {
        let defaultsSuite = "NotchDoTests.calendarSelection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        let firstEvents = FakeReminderEventStore()
        let firstInbox = firstEvents.makeCalendar(title: "Inbox")
        let firstWork = firstEvents.makeCalendar(title: "Work")
        firstEvents.calendarsStub = [firstInbox, firstWork]
        firstEvents.defaultCalendarStub = firstInbox

        let firstStore = RemindersStore(
            eventStore: firstEvents,
            userDefaults: defaults
        )
        await firstStore.start()
        firstStore.selectCalendar(firstWork.calendarIdentifier)

        #expect(
            defaults.string(
                forKey: RemindersStore.selectedCalendarIdentifierDefaultsKey
            ) == firstWork.calendarIdentifier
        )

        let relaunchedEvents = FakeReminderEventStore()
        relaunchedEvents.calendarsStub = [firstInbox, firstWork]
        relaunchedEvents.defaultCalendarStub = firstInbox
        let relaunchedStore = RemindersStore(
            eventStore: relaunchedEvents,
            userDefaults: defaults
        )

        await relaunchedStore.start()

        #expect(relaunchedStore.selectedCalendarIdentifier == firstWork.calendarIdentifier)
        #expect(relaunchedStore.selectedCalendarTitle == "Work")
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

    @Test("Panel interaction recovers after Settings grants access")
    func panelInteractionAuthorizationRecovery() async {
        let events = FakeReminderEventStore()
        events.authorizationStatusStub = .denied
        let store = RemindersStore(eventStore: events)
        await store.start()

        let inbox = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(title: "Recovered", calendar: inbox)
        events.authorizationStatusStub = .fullAccess
        events.calendarsStub = [inbox]
        events.defaultCalendarStub = inbox
        events.fetchedReminders = [reminder]

        await store.refreshAuthorization()

        #expect(store.authorization == .fullAccess)
        #expect(store.selectedCalendar === inbox)
        #expect(store.reminders.first === reminder)
        #expect(events.accessRequestCount == 0)
    }

    @Test("Panel interaction clears revoked content and invalidates an in-flight reload")
    func panelInteractionAuthorizationRevocationDuringReload() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let visible = events.makeReminder(title: "Visible", calendar: inbox)
        events.calendarsStub = [inbox]
        events.fetchedReminders = [visible]
        let store = RemindersStore(eventStore: events)
        await store.start()

        events.completesFetchImmediately = false
        let reload = Task { await store.reload() }
        for _ in 0..<10 where events.pendingFetchCompletions.isEmpty {
            await Task.yield()
        }
        guard let pendingCompletion = events.pendingFetchCompletions.first else {
            Issue.record("Expected an in-flight EventKit fetch")
            return
        }

        events.authorizationStatusStub = .denied
        await store.refreshAuthorization()
        pendingCompletion([visible])
        await reload.value

        #expect(store.authorization == .denied)
        #expect(store.calendars.isEmpty)
        #expect(store.reminders.isEmpty)
        #expect(store.selectedCalendar == nil)
        #expect(store.lastSyncedAt == nil)
        #expect(store.syncState == .idle)
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

    @Test("A stale reload cannot replace reminders from a newly selected calendar")
    func staleReloadAfterCalendarSelection() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        let work = events.makeCalendar(title: "Work")
        let inboxReminder = events.makeReminder(title: "Inbox task", calendar: inbox)
        let workReminder = events.makeReminder(title: "Work task", calendar: work)
        events.calendarsStub = [inbox, work]
        events.defaultCalendarStub = inbox
        events.fetchedReminders = [inboxReminder]

        let store = RemindersStore(eventStore: events)
        await store.start()

        events.completesFetchImmediately = false
        let staleReload = Task { await store.reload() }
        for _ in 0..<10 where events.pendingFetchCompletions.isEmpty {
            await Task.yield()
        }

        store.selectCalendar(work.calendarIdentifier)
        for _ in 0..<10 where events.pendingFetchCompletions.count < 2 {
            await Task.yield()
        }

        guard events.pendingFetchCompletions.count == 2 else {
            Issue.record("Expected one pending fetch for each calendar")
            events.pendingFetchCompletions.forEach { $0([]) }
            await staleReload.value
            return
        }

        let staleCompletion = events.pendingFetchCompletions[0]
        let selectedCompletion = events.pendingFetchCompletions[1]
        selectedCompletion([workReminder])
        for _ in 0..<10 where store.reminders.first !== workReminder {
            await Task.yield()
        }

        staleCompletion([inboxReminder])
        await staleReload.value

        #expect(store.selectedCalendar === work)
        #expect(store.reminders.count == 1)
        #expect(store.reminders.first === workReminder)
        #expect(store.syncState == .synced)
    }

    @Test("Each EventKit fetch order is preserved exactly")
    func fetchedOrder() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let alpha = events.makeReminder(title: "Alpha", calendar: inbox)
        let beta = events.makeReminder(title: "Beta", calendar: inbox)
        let gamma = events.makeReminder(title: "Gamma", calendar: inbox)
        events.fetchedReminders = [gamma, alpha, beta]
        let store = RemindersStore(eventStore: events)
        await store.start()
        #expect(store.reminders.map(\.title) == ["Gamma", "Alpha", "Beta"])

        let aardvark = events.makeReminder(title: "Aardvark", calendar: inbox)
        let zebra = events.makeReminder(title: "Zebra", calendar: inbox)
        events.fetchedReminders = [zebra, beta, aardvark, alpha, gamma]
        await store.reload()
        #expect(store.reminders.map(\.title) == ["Zebra", "Beta", "Aardvark", "Alpha", "Gamma"])
    }

    @Test("Creating a list trims its title, selects it, and rejects blank input")
    func createCalendar() async {
        let events = FakeReminderEventStore()
        let inbox = events.makeCalendar(title: "Inbox")
        events.calendarsStub = [inbox]
        let store = RemindersStore(eventStore: events)
        await store.start()

        #expect(await !store.createCalendar(title: " \n "))
        #expect(events.createdCalendars.isEmpty)

        #expect(await store.createCalendar(title: "  Projects \n"))
        #expect(events.createdCalendars.map(\.title) == ["Projects"])
        #expect(store.selectedCalendarTitle == "Projects")
        #expect(store.calendars.map(\.title) == ["Inbox", "Projects"])
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
        #expect(store.syncErrorMessage != nil)
        store.clearSyncError()
        #expect(store.syncState == .idle)
        #expect(store.syncErrorMessage == nil)
    }

    @Test("Read-only calendars stay readable while every reminder mutation is rejected")
    func readOnlyMutationBoundaries() async {
        let events = FakeReminderEventStore()
        let shared = events.makeCalendar(title: "Shared")
        let reminder = events.makeReminder(title: "Original", calendar: shared)
        events.calendarsStub = [shared]
        events.defaultCalendarStub = shared
        events.fetchedReminders = [reminder]
        events.readOnlyCalendarIdentifiers = [shared.calendarIdentifier]
        let store = RemindersStore(eventStore: events)
        await store.start()

        #expect(store.reminders.first === reminder)
        #expect(!store.selectedCalendarIsWritable)
        #expect(!store.canModify(reminder))
        #expect(await !store.addReminder(title: "Blocked add"))
        #expect(await !store.setCompleted(reminder))
        await store.rename(reminder, to: "Blocked rename")

        var draft = ReminderDraft(reminder: reminder)
        draft.notes = "Blocked notes"
        let updateResult = await store.update(reminder, with: draft, fields: [.notes])
        await store.delete(reminder)

        #expect(!updateResult.succeeded)
        #expect(reminder.title == "Original")
        #expect(reminder.notes == nil)
        #expect(!reminder.isCompleted)
        #expect(events.savedReminders.isEmpty)
        #expect(events.removedReminders.isEmpty)
        #expect(store.reminders.first === reminder)
    }

    @Test("Writability is evaluated per reminder calendar")
    func reminderCalendarWritability() async {
        let events = FakeReminderEventStore()
        let shared = events.makeCalendar(title: "Shared")
        let personal = events.makeCalendar(title: "Personal")
        let sharedReminder = events.makeReminder(title: "Shared task", calendar: shared)
        let personalReminder = events.makeReminder(title: "Personal task", calendar: personal)
        events.calendarsStub = [shared, personal]
        events.defaultCalendarStub = shared
        events.fetchedReminders = [sharedReminder]
        events.readOnlyCalendarIdentifiers = [shared.calendarIdentifier]
        let store = RemindersStore(eventStore: events)
        await store.start()

        #expect(!store.canModify(sharedReminder))
        #expect(store.canModify(personalReminder))
        #expect(await store.setCompleted(personalReminder))
        #expect(events.savedReminders.last === personalReminder)
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
        let failedCompletion = await store.setCompleted(first)
        #expect(!failedCompletion)
        #expect(!first.isCompleted)
        #expect(store.reminders.contains { $0 === first })
        guard case .failed = store.syncState else {
            Issue.record("A completion save error should be surfaced")
            return
        }

        events.saveError = nil
        let successfulCompletion = await store.setCompleted(first)
        #expect(successfulCompletion)
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
        draft.hasDueTime = true
        draft.dueDate = fixedDate(2026, 9, 12, hour: 16, minute: 45)
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

    @Test("Date-only updates omit time; disabling due values and recurrence clears both")
    func dueDateAndRecurrenceClearing() async {
        let defaultsSuite = "NotchDoTests.dueMode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
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
        let store = RemindersStore(eventStore: events, userDefaults: defaults)
        await store.start()

        var draft = ReminderDraft(reminder: reminder)
        draft.hasDueDate = true
        draft.hasDueTime = false
        draft.dueDate = fixedDate(2026, 10, 2, hour: 22, minute: 10)
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
        draft.hasDueTime = false
        draft.recurrence = .never
        await store.update(reminder, with: draft, fields: [.dueDate, .recurrence])
        #expect(reminder.dueDateComponents == nil)
        #expect(store.dueMode(for: reminder) == .none)
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
        let titleOnlyResult = await store.update(reminder, with: draft, fields: [.title])
        #expect(titleOnlyResult.succeeded)
        #expect(titleOnlyResult.rejectedFields == [.title])
        #expect(events.savedReminders.isEmpty)

        draft.notes = "Still saved"
        let mixedResult = await store.update(
            reminder,
            with: draft,
            fields: [.title, .notes]
        )
        #expect(mixedResult.succeeded)
        #expect(mixedResult.rejectedFields == [.title])
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
        draft.hasDueTime = false
        draft.priority = .high
        draft.recurrence = .daily
        let result = await store.update(
            reminder,
            with: draft,
            fields: [.title, .notes, .dueDate, .priority, .recurrence]
        )

        #expect(!result.succeeded)
        #expect(result.rejectedFields.isEmpty)
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
