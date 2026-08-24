import Testing
@testable import NotchDo

@Suite("Reminder search state")
struct ReminderSearchStateTests {
    @Test("Present requests focus every time")
    func repeatedPresentationRestoresFocus() {
        var state = ReminderSearchState()

        state.present()
        let firstRequest = state.focusRequest
        state.query = "plan"
        state.present()

        #expect(state.isPresented)
        #expect(state.query == "plan")
        #expect(state.focusRequest != firstRequest)
    }

    @Test("Clear keeps search open and requests focus")
    func clear() {
        var state = ReminderSearchState()
        state.present()
        state.query = "plan"
        let priorRequest = state.focusRequest

        state.clear()

        #expect(state.isPresented)
        #expect(state.query.isEmpty)
        #expect(state.focusRequest != priorRequest)
    }

    @Test("Dismiss clears the ephemeral query")
    func dismiss() {
        var state = ReminderSearchState()
        state.present()
        state.query = "plan"

        state.dismiss()

        #expect(!state.isPresented)
        #expect(state.query.isEmpty)
    }
}
