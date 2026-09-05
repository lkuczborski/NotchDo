import Foundation
import Testing
@testable import NotchDo

@Suite("Reminder sync status formatter")
struct ReminderSyncStatusFormatterTests {
    @Test("Update timestamps use stable useful boundaries")
    func updateTimestampBoundaries() {
        let now = fixedDate(2026, 8, 24, hour: 15)
        let formatter = ReminderSyncStatusFormatter(
            now: { now },
            calendar: fixedCalendar(),
            timeText: { date in
                let components = fixedCalendar().dateComponents([.hour, .minute], from: date)
                return String(format: "%02d:%02d", components.hour!, components.minute!)
            },
            dateText: { date in
                let components = fixedCalendar().dateComponents([.month, .day], from: date)
                return "\(components.month!)/\(components.day!)"
            }
        )

        #expect(
            formatter.updatedText(
                for: fixedDate(2026, 8, 24, hour: 14, minute: 59)
                    .addingTimeInterval(30)
            ) == "Updated just now"
        )
        #expect(
            formatter.updatedText(for: fixedDate(2026, 8, 24, hour: 14, minute: 55))
                == "Updated 5m ago"
        )
        #expect(
            formatter.updatedText(for: fixedDate(2026, 8, 24, hour: 11, minute: 30))
                == "Updated at 11:30"
        )
        #expect(
            formatter.updatedText(for: fixedDate(2026, 8, 23, hour: 18, minute: 5))
                == "Updated yesterday at 18:05"
        )
        #expect(
            formatter.updatedText(for: fixedDate(2026, 8, 20, hour: 9, minute: 15))
                == "Updated 8/20 at 09:15"
        )
        #expect(
            formatter.updatedText(for: fixedDate(2026, 8, 24, hour: 16))
                == "Updated just now"
        )
    }
}
