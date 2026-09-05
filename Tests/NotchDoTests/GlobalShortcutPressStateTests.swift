import Testing
@testable import NotchDo

struct GlobalShortcutPressStateTests {
    @Test func heldShortcutActivatesOnlyOnceUntilReleased() {
        var state = GlobalShortcutPressState()
        let activations = [true, true, true, false, true].map {
            state.update(isPressed: $0)
        }
        #expect(activations == [true, false, false, false, true])
    }
}
