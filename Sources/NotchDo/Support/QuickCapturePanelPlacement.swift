import CoreGraphics

enum QuickCapturePanelPlacement {
    static func origin(panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2 + visibleFrame.height * 0.16
        )
    }
}
