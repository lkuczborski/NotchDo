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
