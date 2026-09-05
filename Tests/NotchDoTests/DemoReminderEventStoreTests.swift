#if NOTCHDO_DEMO
import EventKit
import Foundation
import Testing
@testable import NotchDo

@Suite("Isolated demo fixtures", .serialized)
@MainActor
struct DemoReminderEventStoreTests {
    @Test("Fixtures filter by list, protect read-only content, and never persist across instances")
    func fixtureIsolation() async throws {
        let fake = DemoReminderEventStore(now: Date(timeIntervalSince1970: 1_788_566_400), calendar: Calendar(identifier: .gregorian))
        let lists = fake.calendars(for: .reminder)
        #expect(Set(lists.map(\.calendarIdentifier)).count == 4)
        let studio = try #require(lists.first { $0.title == "Studio" })
        let store = RemindersStore(eventStore: fake)
        await store.start()
        #expect(store.selectedCalendarIdentifier == studio.calendarIdentifier)
        #expect(store.reminders.count == 8)
        #expect(store.reminders.allSatisfy { $0.calendar === studio })
        let item = fake.makeReminder()
        item.title = "Fictional capture"
        item.calendar = studio
        try fake.save(item, commit: true)
        await store.reload()
        #expect(store.reminders.count == 9)
        try fake.remove(item, commit: true)
        await store.reload()
        #expect(store.reminders.count == 8)
        let readOnly = try #require(lists.first { $0.title == "Shared inspiration" })
        item.calendar = readOnly
        #expect(throws: (any Error).self) { try fake.save(item, commit: true) }
        let fresh = RemindersStore(eventStore: DemoReminderEventStore())
        await fresh.start()
        #expect(fresh.reminders.count == 8)
    }

    @Test("Permission and first-list scenarios stay entirely in memory")
    func onboarding() async throws {
        let fake = DemoReminderEventStore(scenario: "permission")
        #expect(fake.authorizationStatus() == .notDetermined)
        #expect(try await fake.requestFullAccessToReminders())
        #expect(fake.authorizationStatus() == .fullAccess)
        #expect(fake.calendars(for: .reminder).isEmpty)
        let list = try fake.createReminderCalendar(title: "Fresh ideas")
        #expect(fake.defaultCalendarForNewReminders() === list)
        #expect(DemoReminderEventStore(scenario: "first-list").calendars(for: .reminder).isEmpty)
    }
}
#endif
