import Foundation

struct ReminderSyncStatusFormatter {
    private let now: () -> Date
    private let calendar: Calendar
    private let timeText: (Date) -> String
    private let dateText: (Date) -> String

    init(
        now: @escaping () -> Date,
        calendar: Calendar,
        timeText: @escaping (Date) -> String,
        dateText: @escaping (Date) -> String
    ) {
        self.now = now
        self.calendar = calendar
        self.timeText = timeText
        self.dateText = dateText
    }

    func updatedText(for date: Date) -> String {
        let currentDate = now()
        let elapsed = max(0, currentDate.timeIntervalSince(date))

        if elapsed < 60 {
            return "Updated just now"
        }
        if elapsed < 60 * 60 {
            return "Updated \(Int(elapsed / 60))m ago"
        }
        if calendar.isDate(date, inSameDayAs: currentDate) {
            return "Updated at \(timeText(date))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Updated yesterday at \(timeText(date))"
        }
        return "Updated \(dateText(date)) at \(timeText(date))"
    }
}

extension ReminderSyncStatusFormatter {
    static var live: ReminderSyncStatusFormatter {
        ReminderSyncStatusFormatter(
            now: Date.init,
            calendar: .autoupdatingCurrent,
            timeText: { date in
                date.formatted(date: .omitted, time: .shortened)
            },
            dateText: { date in
                date.formatted(.dateTime.month(.abbreviated).day())
            }
        )
    }
}
