import Foundation
import Testing
@testable import NotchDo

@Suite("Quick capture state")
struct QuickCaptureStateTests {
    @Test("Whitespace titles cannot be submitted")
    func titleValidation() {
        var state = QuickCaptureState(now: Date(timeIntervalSince1970: 0))
        state.title = " \n "
        #expect(!state.canSubmit)
        state.title = "Call the dentist"
        #expect(state.canSubmit)
    }

    @Test("Capture details map to the shared reminder draft")
    func reminderDraftMapping() {
        let dueDate = Date(timeIntervalSince1970: 1_800)
        var state = QuickCaptureState(now: .distantPast, calendarIdentifier: "inbox")
        state.title = "Call the dentist"
        state.notes = "Ask about Thursday"
        state.includesDueDate = true
        state.dueDate = dueDate

        let draft = state.reminderDraft
        #expect(draft.title == "Call the dentist")
        #expect(draft.notes == "Ask about Thursday")
        #expect(draft.hasDueDate)
        #expect(!draft.hasDueTime)
        #expect(draft.dueDate == dueDate)
    }

    @Test("Reset clears previous input and follows the current list")
    func reset() {
        let now = Date(timeIntervalSince1970: 100)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var state = QuickCaptureState(now: .distantPast, calendarIdentifier: "old")
        state.title = "Stale"
        state.notes = "Stale notes"
        state.includesDueDate = true

        state.reset(now: now, selectedCalendarIdentifier: "work", calendar: calendar)

        #expect(state.title.isEmpty)
        #expect(state.notes.isEmpty)
        #expect(!state.includesDueDate)
        #expect(state.calendarIdentifier == "work")
        #expect(state.dueDate == now.addingTimeInterval(3_600))
    }
}
