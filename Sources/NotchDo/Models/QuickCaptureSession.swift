import Foundation
import Observation

@MainActor
@Observable
final class QuickCaptureSession {
    private(set) var state = QuickCaptureState()
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var presentationID = 0
    private let store: RemindersStore
    private let now: () -> Date
    private let calendar: Calendar

    init(
        store: RemindersStore,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    var title: String {
        get { state.title }
        set { state.title = newValue }
    }

    var notes: String {
        get { state.notes }
        set { state.notes = newValue }
    }

    var includesDueDate: Bool {
        get { state.includesDueDate }
        set { state.includesDueDate = newValue }
    }

    var dueDate: Date {
        get { state.dueDate }
        set { state.dueDate = newValue }
    }

    var calendarIdentifier: String? {
        get { state.calendarIdentifier }
        set { state.calendarIdentifier = newValue }
    }

    var canSubmit: Bool {
        state.canSubmit && !isSaving && store.writableCalendars.contains {
            $0.calendarIdentifier == state.calendarIdentifier
        }
    }

    func reconcileDestination() {
        let writable = store.writableCalendars
        guard !writable.contains(where: { $0.calendarIdentifier == state.calendarIdentifier }) else { return }
        state.calendarIdentifier = writable.first(where: {
            $0.calendarIdentifier == store.selectedCalendarIdentifier
        })?.calendarIdentifier ?? writable.first?.calendarIdentifier
    }

    func schedule(_ schedule: ReminderQuickSchedule) {
        var draft = state.reminderDraft
        schedule.apply(to: &draft, now: now(), calendar: calendar)
        state.includesDueDate = draft.hasDueDate
        state.dueDate = draft.dueDate
    }

    func isScheduled(_ schedule: ReminderQuickSchedule) -> Bool {
        guard state.includesDueDate, schedule != .clearDate else { return false }
        var draft = state.reminderDraft
        schedule.apply(to: &draft, now: now(), calendar: calendar)
        return calendar.isDate(draft.dueDate, inSameDayAs: state.dueDate)
    }

    func prepare() {
        presentationID &+= 1
        state.reset(
            now: now(),
            selectedCalendarIdentifier: store.selectedCalendarIdentifier,
            calendar: calendar
        )
        isSaving = false
        errorMessage = nil
        reconcileDestination()
    }

    func submit() async -> Bool {
        guard state.canSubmit, !isSaving else { return false }
        guard canSubmit else {
            errorMessage = "Choose a writable Reminders list and try again."
            return false
        }
        let submittedPresentation = presentationID
        isSaving = true
        errorMessage = nil
        let didSave = await store.addReminder(
            draft: state.reminderDraft,
            calendarIdentifier: state.calendarIdentifier
        )
        guard presentationID == submittedPresentation else { return false }
        isSaving = false
        if !didSave {
            errorMessage = store.syncErrorMessage
                ?? "Choose a writable Reminders list and try again."
        }
        return didSave
    }
}
