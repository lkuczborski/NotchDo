import Testing
@testable import NotchDo

@Suite("Notch menu tracking", .serialized)
@MainActor
struct NotchMenuTrackingStateTests {
    @Test("Menu tracking keeps the panel expanded until the final menu closes")
    func keepsPanelExpanded() async throws {
        let interaction = NotchInteractionModel()
        var tracking = NotchMenuTrackingState()
        interaction.updatePointerInside(true)

        if tracking.beginTracking() {
            interaction.updateTransientInteraction(true)
        }
        #expect(tracking.isTracking)
        let nestedBecameActive = tracking.beginTracking()
        #expect(!nestedBecameActive)
        interaction.updatePointerInside(false)
        #expect(interaction.isExpanded)

        let nestedBecameInactive = tracking.endTracking()
        #expect(!nestedBecameInactive)
        #expect(interaction.isExpanded)
        if tracking.endTracking() {
            interaction.updateTransientInteraction(false)
        }
        #expect(!tracking.isTracking)
        #expect(interaction.isExpanded)
        try await Task.sleep(for: .milliseconds(150))
        #expect(!interaction.isExpanded)
    }

    @Test("Unbalanced menu-end notifications and reset are safe")
    func notificationBoundaries() {
        var tracking = NotchMenuTrackingState()

        let unmatchedEnd = tracking.endTracking()
        let inactiveReset = tracking.reset()
        let becameActive = tracking.beginTracking()
        let activeReset = tracking.reset()
        #expect(!unmatchedEnd)
        #expect(!inactiveReset)
        #expect(becameActive)
        #expect(activeReset)
        #expect(!tracking.isTracking)
        let endAfterReset = tracking.endTracking()
        #expect(!endAfterReset)
    }
}
