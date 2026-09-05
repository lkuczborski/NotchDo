import Foundation

enum ReminderDisplayState: Equatable {
    case needsPermission
    case requestingPermission
    case permissionDenied
    case permissionRestricted
    case noCalendars
    case noSelectedCalendar
    case initialLoading
    case emptyList(isReadOnly: Bool)
    case reminders(isReadOnly: Bool)

    init(
        authorization: ReminderAuthorizationState,
        calendarCount: Int,
        hasSelectedCalendar: Bool,
        reminderCount: Int,
        selectedCalendarIsWritable: Bool,
        syncState: ReminderSyncState,
        lastSyncedAt: Date?
    ) {
        switch authorization {
        case .notDetermined:
            self = .needsPermission
        case .requesting:
            self = .requestingPermission
        case .denied:
            self = .permissionDenied
        case .restricted:
            self = .permissionRestricted
        case .fullAccess:
            guard calendarCount > 0 else {
                self = .noCalendars
                return
            }
            guard hasSelectedCalendar else {
                self = .noSelectedCalendar
                return
            }

            let isReadOnly = !selectedCalendarIsWritable
            if case .syncing = syncState, lastSyncedAt == nil, reminderCount == 0 {
                self = .initialLoading
            } else if reminderCount == 0 {
                self = .emptyList(isReadOnly: isReadOnly)
            } else {
                self = .reminders(isReadOnly: isReadOnly)
            }
        }
    }
}
