import AppKit
import EventKit
import SwiftUI

extension Color {
    static let notchAccent = Color(red: 0.72, green: 0.95, blue: 0.43)
}

extension EKCalendar {
    var notchColor: Color {
        guard let cgColor,
              let color = NSColor(cgColor: cgColor) else {
            return .notchAccent
        }
        return Color(nsColor: color)
    }
}

extension RemindersStore {
    var selectedCalendarColor: Color {
        selectedCalendar?.notchColor ?? .notchAccent
    }
}
