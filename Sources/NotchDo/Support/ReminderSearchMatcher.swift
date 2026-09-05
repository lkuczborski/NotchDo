import EventKit
import Foundation

enum ReminderSearchMatcher {
    static func matches(
        _ candidate: String,
        query: String,
        locale: Locale = .current
    ) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }

        return candidate.range(
            of: normalizedQuery,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: locale
        ) != nil
    }

    static func filter(
        _ reminders: [EKReminder],
        query: String,
        locale: Locale = .current
    ) -> [EKReminder] {
        reminders.filter { reminder in
            matches(reminder.title, query: query, locale: locale)
        }
    }
}
