import AppKit
import EventKit
import SwiftUI

extension EKCalendar {
    var notchColor: Color {
        guard let cgColor,
              let color = NSColor(cgColor: cgColor) else {
            return .notchAccent
        }
        return Color(nsColor: color)
    }
}
