import SwiftUI

extension RemindersStore {
    var selectedCalendarColor: Color {
        selectedCalendar?.notchColor ?? .notchAccent
    }
}
