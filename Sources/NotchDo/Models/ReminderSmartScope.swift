import Foundation

enum ReminderSmartScope: String, CaseIterable, Identifiable, Sendable {
    case today
    case overdue
    case scheduled
    case allOpen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .overdue: "Overdue"
        case .scheduled: "Scheduled"
        case .allOpen: "All Open"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "calendar"
        case .overdue: "exclamationmark.circle"
        case .scheduled: "calendar.badge.clock"
        case .allOpen: "tray.full"
        }
    }
}
