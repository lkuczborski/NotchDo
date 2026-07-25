import AppKit

struct NotchMetrics: Equatable {
    let collapsedSize: CGSize
    let expandedSize: CGSize
    let bridgeHeight: CGFloat
    let anchorX: CGFloat
    let screenTop: CGFloat
    let notchTriggerRect: CGRect

    static func resolve(for screen: NSScreen) -> NotchMetrics {
        resolve(for: NotchScreenGeometry(screen: screen))
    }

    static func resolve(for geometry: NotchScreenGeometry) -> NotchMetrics {
        let fallbackWidth: CGFloat = 214
        let fallbackHeight: CGFloat = 34
        let topInset = geometry.safeAreaTopInset

        if let leftArea = geometry.auxiliaryTopLeftArea,
           let rightArea = geometry.auxiliaryTopRightArea {
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
                    screenTop: geometry.frame.maxY,
                    notchTriggerRect: CGRect(
                        x: leftArea.maxX,
                        y: geometry.frame.maxY - topInset,
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
            anchorX: geometry.frame.midX,
            screenTop: geometry.frame.maxY,
            notchTriggerRect: CGRect(
                x: geometry.frame.midX - fallbackWidth / 2,
                y: geometry.frame.maxY - fallbackBridgeHeight,
                width: fallbackWidth,
                height: fallbackBridgeHeight + 2
            )
        )
    }
}
