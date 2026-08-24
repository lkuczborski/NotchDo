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

    init(store: RemindersStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
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

    var canSubmit: Bool { state.canSubmit && !isSaving }

    func prepare() {
        presentationID &+= 1
        state.reset(
            now: now(),
            selectedCalendarIdentifier: store.selectedCalendarIdentifier
        )
        isSaving = false
        errorMessage = nil
    }

    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSaving = true
        errorMessage = nil
        let didSave = await store.addReminder(
            draft: state.reminderDraft,
            calendarIdentifier: state.calendarIdentifier
        )
        isSaving = false
        if !didSave {
            errorMessage = store.syncErrorMessage
                ?? "Choose a writable Reminders list and try again."
        }
        return didSave
    }
}
