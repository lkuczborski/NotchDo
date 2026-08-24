import EventKit
import SwiftUI

extension RemindersStore {
    var selectedCalendarColor: Color {
        selectedSmartScope == nil ? selectedCalendar?.notchColor ?? .notchAccent : .notchAccent
    }

    func color(for reminder: EKReminder) -> Color {
        reminder.calendar?.notchColor ?? .notchAccent
    }
}
