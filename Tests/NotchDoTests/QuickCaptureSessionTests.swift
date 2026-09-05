import Foundation
import Testing
@testable import NotchDo

@Suite("Quick capture session", .serialized)
@MainActor
struct QuickCaptureSessionTests {
    @Test("Quick dates save date-only components and can be cleared")
    func quickDates() async throws {
        let fake = FakeReminderEventStore()
        fake.calendarsStub = [fake.makeCalendar(title: "Inbox")]
        let store = RemindersStore(eventStore: fake)
        await store.start()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = QuickCaptureSession(store: store, now: { now }, calendar: calendar)
        session.prepare()
        session.title = "Tomorrow task"
        session.schedule(.tomorrow)
        #expect(session.isScheduled(.tomorrow))
        #expect(!session.isScheduled(.today))
        #expect(!session.isScheduled(.nextWeek))
        #expect(session.dueDate == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
        #expect(await session.submit())
        let components = try #require(fake.savedReminders.last?.dueDateComponents)
        #expect(components.hour == nil)
        #expect(components.minute == nil)
        #expect(components.timeZone == nil)
        session.schedule(.clearDate)
        #expect(!session.includesDueDate)
        #expect(!session.isScheduled(.tomorrow))
    }
    @Test("Capture chooses a writable destination and reconciles removed lists")
    func writableDestination() async {
        let fake = FakeReminderEventStore()
        let shared = fake.makeCalendar(title: "Shared")
        let inbox = fake.makeCalendar(title: "Inbox")
        fake.calendarsStub = [shared, inbox]
        fake.defaultCalendarStub = shared
        fake.readOnlyCalendarIdentifiers = [shared.calendarIdentifier]
        let store = RemindersStore(eventStore: fake)
        await store.start()
        let session = QuickCaptureSession(store: store)
        session.prepare()
        session.title = "Keep this draft"
        #expect(session.calendarIdentifier == inbox.calendarIdentifier)
        #expect(session.canSubmit)
        fake.calendarsStub = [shared]
        await store.refreshAuthorization()
        session.reconcileDestination()
        #expect(session.calendarIdentifier == nil)
        #expect(!session.canSubmit)
        #expect(session.title == "Keep this draft")
    }

    @Test("An older save cannot complete a new presentation")
    func staleSave() async {
        let fake = FakeReminderEventStore()
        let inbox = fake.makeCalendar(title: "Inbox")
        fake.calendarsStub = [inbox]
        let store = RemindersStore(eventStore: fake)
        await store.start()
        let session = QuickCaptureSession(store: store)
        session.prepare()
        session.title = "First task"
        fake.completesFetchImmediately = false
        let submission = Task { await session.submit() }
        while fake.pendingFetchCompletions.isEmpty { await Task.yield() }
        session.prepare()
        session.title = "Second task"
        fake.pendingFetchCompletions.removeFirst()(fake.fetchedReminders)
        #expect(await submission.value == false)
        #expect(session.title == "Second task")
        #expect(!session.isSaving)
        #expect(session.errorMessage == nil)
        #expect(fake.savedReminders.count == 1)
    }

    @Test("Failed saves preserve capture input for retry")
    func saveFailure() async {
        let fake = FakeReminderEventStore()
        fake.calendarsStub = [fake.makeCalendar(title: "Inbox")]
        let store = RemindersStore(eventStore: fake)
        await store.start()
        let session = QuickCaptureSession(store: store)
        session.prepare()
        session.title = "Keep me"
        session.notes = "Keep details"
        fake.saveError = TestFailure.requested
        #expect(await session.submit() == false)
        #expect(session.title == "Keep me")
        #expect(session.notes == "Keep details")
        #expect(session.errorMessage != nil)
        #expect(session.canSubmit)
    }
}
