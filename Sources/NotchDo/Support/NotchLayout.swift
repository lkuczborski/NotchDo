import AppKit
import Combine

struct NotchMetrics: Equatable {
    let collapsedSize: CGSize
    let expandedSize: CGSize
    let bridgeHeight: CGFloat
    let anchorX: CGFloat
    let screenTop: CGFloat
    let notchTriggerRect: CGRect

    static func resolve(for screen: NSScreen) -> NotchMetrics {
        let fallbackWidth: CGFloat = 214
        let fallbackHeight: CGFloat = 34
        let topInset = screen.safeAreaInsets.top

        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            let hardwareNotchWidth = rightArea.minX - leftArea.maxX

            if topInset > 0, hardwareNotchWidth >= 80, hardwareNotchWidth <= 400 {
                return NotchMetrics(
                    collapsedSize: CGSize(
                        width: hardwareNotchWidth,
                        height: topInset
                    ),
                    expandedSize: CGSize(width: 440, height: 470),
                    bridgeHeight: topInset,
                    anchorX: (leftArea.maxX + rightArea.minX) / 2,
                    screenTop: screen.frame.maxY,
                    notchTriggerRect: CGRect(
                        x: leftArea.maxX,
                        y: screen.frame.maxY - topInset,
                        width: hardwareNotchWidth,
                        height: topInset + 2
                    )
                )
            }
        }

        let fallbackBridgeHeight = max(fallbackHeight, topInset)
        return NotchMetrics(
            collapsedSize: CGSize(
                width: fallbackWidth,
                height: fallbackBridgeHeight
            ),
            expandedSize: CGSize(width: 440, height: 470),
            bridgeHeight: fallbackBridgeHeight,
            anchorX: screen.frame.midX,
            screenTop: screen.frame.maxY,
            notchTriggerRect: CGRect(
                x: screen.frame.midX - fallbackWidth / 2,
                y: screen.frame.maxY - fallbackBridgeHeight,
                width: fallbackWidth,
                height: fallbackBridgeHeight + 2
            )
        )
    }
}

@MainActor
final class NotchLayoutModel: ObservableObject {
    @Published private(set) var metrics: NotchMetrics

    init(screen: NSScreen) {
        metrics = .resolve(for: screen)
    }

    func update(for screen: NSScreen) {
        let newMetrics = NotchMetrics.resolve(for: screen)
        if newMetrics != metrics {
            metrics = newMetrics
        }
    }
}
