import Foundation
import Testing
@testable import NotchDo

@Suite("Smart reminder scope membership")
struct ReminderSmartScopeMembershipTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    @Test("Open and scheduled scopes exclude completed reminders and preserve undated semantics")
    func openAndScheduled() {
        let policy = policyAt(2026, 8, 24, hour: 12)
        let due = components(2026, 8, 25)

        #expect(policy.contains(isCompleted: false, dueDateComponents: nil, in: .allOpen))
        #expect(!policy.contains(isCompleted: true, dueDateComponents: nil, in: .allOpen))
        #expect(!policy.contains(isCompleted: false, dueDateComponents: nil, in: .scheduled))
        #expect(policy.contains(isCompleted: false, dueDateComponents: due, in: .scheduled))
        #expect(!policy.contains(isCompleted: true, dueDateComponents: due, in: .scheduled))
    }

    @Test("All-day reminders use local day boundaries instead of midnight as a deadline")
    func allDayBoundaries() {
        let policy = policyAt(2026, 8, 24, hour: 18)

        #expect(policy.contains(
            isCompleted: false,
            dueDateComponents: components(2026, 8, 24),
            in: .today
        ))
        #expect(!policy.contains(
            isCompleted: false,
            dueDateComponents: components(2026, 8, 24),
            in: .overdue
        ))
        #expect(policy.contains(
            isCompleted: false,
            dueDateComponents: components(2026, 8, 23),
            in: .overdue
        ))
    }

    @Test("Timed reminders compare exact instants and may be both Today and Overdue")
    func timedBoundaries() {
        let policy = policyAt(2026, 8, 24, hour: 12)
        let earlierToday = components(2026, 8, 24, hour: 11, minute: 59)
        let now = components(2026, 8, 24, hour: 12)

        #expect(policy.contains(isCompleted: false, dueDateComponents: earlierToday, in: .today))
        #expect(policy.contains(isCompleted: false, dueDateComponents: earlierToday, in: .overdue))
        #expect(!policy.contains(isCompleted: false, dueDateComponents: now, in: .overdue))
    }

    @Test("DST transition dates remain in the user's local Today scope")
    func daylightSavingBoundary() {
        let policy = policyAt(2026, 3, 8, hour: 3, minute: 15)
        let beforeJump = components(2026, 3, 8, hour: 1, minute: 59)
        let afterJump = components(2026, 3, 8, hour: 3, minute: 30)

        #expect(policy.contains(isCompleted: false, dueDateComponents: beforeJump, in: .today))
        #expect(policy.contains(isCompleted: false, dueDateComponents: beforeJump, in: .overdue))
        #expect(policy.contains(isCompleted: false, dueDateComponents: afterJump, in: .today))
        #expect(!policy.contains(isCompleted: false, dueDateComponents: afterJump, in: .overdue))
    }

    private func policyAt(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        minute: Int = 0
    ) -> ReminderSmartScopeMembership {
        let now = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
        return ReminderSmartScopeMembership(now: now, calendar: calendar)
    }

    private func components(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int? = nil,
        minute: Int? = nil
    ) -> DateComponents {
        DateComponents(
            calendar: calendar,
            timeZone: hour == nil ? nil : calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    }
}
