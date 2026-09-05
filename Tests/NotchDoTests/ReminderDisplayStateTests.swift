import Foundation
import Testing
@testable import NotchDo

@Suite("Reminder display state")
struct ReminderDisplayStateTests {
    @Test("Authorization states stay distinct")
    func authorizationStates() {
        #expect(state(authorization: .notDetermined) == .needsPermission)
        #expect(state(authorization: .requesting) == .requestingPermission)
        #expect(state(authorization: .denied) == .permissionDenied)
        #expect(state(authorization: .restricted) == .permissionRestricted)
    }

    @Test("A missing calendar is distinct from an empty selected list")
    func calendarAndEmptyStates() {
        #expect(
            state(calendarCount: 0, hasSelectedCalendar: false) == .noCalendars
        )
        #expect(
            state(calendarCount: 1, hasSelectedCalendar: false) == .noSelectedCalendar
        )
        #expect(
            state(selectedCalendarIsWritable: true) == .emptyList(isReadOnly: false)
        )
        #expect(
            state(selectedCalendarIsWritable: false) == .emptyList(isReadOnly: true)
        )
    }

    @Test("Initial loading, refresh, success, and failure transition deterministically")
    func syncTransitions() {
        let syncDate = fixedDate(2026, 8, 24, hour: 12)

        #expect(
            state(syncState: .syncing, lastSyncedAt: nil) == .initialLoading
        )
        #expect(
            state(syncState: .synced, lastSyncedAt: syncDate)
                == .emptyList(isReadOnly: false)
        )
        #expect(
            state(syncState: .syncing, lastSyncedAt: syncDate)
                == .emptyList(isReadOnly: false)
        )
        #expect(
            state(syncState: .failed("Offline"), lastSyncedAt: syncDate)
                == .emptyList(isReadOnly: false)
        )
        #expect(
            state(reminderCount: 2, syncState: .failed("Offline"), lastSyncedAt: syncDate)
                == .reminders(isReadOnly: false)
        )
    }

    private func state(
        authorization: ReminderAuthorizationState = .fullAccess,
        calendarCount: Int = 1,
        hasSelectedCalendar: Bool = true,
        reminderCount: Int = 0,
        selectedCalendarIsWritable: Bool = true,
        syncState: ReminderSyncState = .synced,
        lastSyncedAt: Date? = fixedDate(2026, 8, 24, hour: 12)
    ) -> ReminderDisplayState {
        ReminderDisplayState(
            authorization: authorization,
            calendarCount: calendarCount,
            hasSelectedCalendar: hasSelectedCalendar,
            reminderCount: reminderCount,
            selectedCalendarIsWritable: selectedCalendarIsWritable,
            syncState: syncState,
            lastSyncedAt: lastSyncedAt
        )
    }
}
