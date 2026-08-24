import EventKit
import Foundation
import Testing
@testable import NotchDo

@Suite("Reminder search matcher")
struct ReminderSearchMatcherTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test("Matching ignores case and diacritics")
    func caseAndDiacriticInsensitive() {
        #expect(ReminderSearchMatcher.matches("RéSUMé trip", query: "resume", locale: locale))
        #expect(ReminderSearchMatcher.matches("Call AMY", query: "amy", locale: locale))
        #expect(!ReminderSearchMatcher.matches("Call Amy", query: "Ben", locale: locale))
    }

    @Test("Blank queries show every candidate")
    func blankQuery() {
        #expect(ReminderSearchMatcher.matches("Any reminder", query: "  \n", locale: locale))
    }

    @Test("Filtering preserves EventKit order and reminder identity")
    @MainActor
    func stableOrderAndIdentity() throws {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let first = events.makeReminder(title: "Alpha plan", calendar: calendar)
        let skipped = events.makeReminder(title: "Beta plan", calendar: calendar)
        let last = events.makeReminder(title: "Alpha follow-up", calendar: calendar)

        let matches = ReminderSearchMatcher.filter(
            [first, skipped, last],
            query: "alpha",
            locale: locale
        )

        #expect(matches.map(\.calendarItemIdentifier) == [
            first.calendarItemIdentifier,
            last.calendarItemIdentifier
        ])
        #expect(matches[0] === first)
        #expect(matches[1] === last)
    }
}
