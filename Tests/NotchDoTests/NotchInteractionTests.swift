import Testing
@testable import NotchDo

@Suite("Notch interaction", .serialized)
@MainActor
struct NotchInteractionTests {
    @Test("Pointer entry and exit drive expansion exactly once per transition")
    func pointerTransitions() {
        let model = NotchInteractionModel()
        var changes: [Bool] = []
        model.onExpansionChange = { changes.append($0) }

        model.updatePointerInside(true)
        model.updatePointerInside(true)
        #expect(model.isPointerInside)
        #expect(model.isExpanded)
        #expect(changes == [true])

        model.updatePointerInside(false)
        #expect(!model.isPointerInside)
        #expect(!model.isExpanded)
        #expect(changes == [true, false])
    }

    @Test("Transient interaction prevents premature collapse")
    func transientInteraction() async throws {
        let model = NotchInteractionModel()
        model.updateTransientInteraction(true)
        #expect(model.isExpanded)

        model.collapse()
        model.updatePointerInside(false)
        #expect(model.isExpanded)

        model.updateTransientInteraction(false)
        #expect(model.isExpanded)
        try await Task.sleep(for: .milliseconds(150))
        #expect(!model.isExpanded)
    }

    @Test("Re-entry cancels a scheduled transient dismissal")
    func reentryCancelsDismissal() async throws {
        let model = NotchInteractionModel()
        model.updateTransientInteraction(true)
        model.updateTransientInteraction(false)
        try await Task.sleep(for: .milliseconds(30))
        model.updatePointerInside(true)
        try await Task.sleep(for: .milliseconds(120))
        #expect(model.isExpanded)
        #expect(model.isPointerInside)
    }

    @Test("Manual transitions are idempotent")
    func manualTransitions() {
        let model = NotchInteractionModel()
        var changes: [Bool] = []
        model.onExpansionChange = { changes.append($0) }

        model.expand()
        model.expand()
        model.collapse()
        model.collapse()

        #expect(changes == [true, false])
    }
}
