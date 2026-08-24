import CoreGraphics
import Testing
@testable import NotchDo

@Suite("Quick capture panel placement")
struct QuickCapturePanelPlacementTests {
    @Test("Panel is horizontally centered and Spotlight-high on the active display")
    func centeredOnDisplay() {
        let visibleFrame = CGRect(x: 1440, y: 40, width: 1920, height: 1040)
        let panelSize = CGSize(width: 660, height: 220)

        let origin = QuickCapturePanelPlacement.origin(
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        #expect(origin.x == 2070)
        #expect(abs(origin.y - 616.4) < 0.001)
        #expect(origin.x + panelSize.width / 2 == visibleFrame.midX)
        #expect(origin.y > visibleFrame.midY - panelSize.height / 2)
    }
}
