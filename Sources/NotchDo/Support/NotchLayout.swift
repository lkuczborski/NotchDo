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

struct NotchScreenGeometry {
    let frame: CGRect
    let safeAreaTopInset: CGFloat
    let auxiliaryTopLeftArea: CGRect?
    let auxiliaryTopRightArea: CGRect?

    init(
        frame: CGRect,
        safeAreaTopInset: CGFloat,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?
    ) {
        self.frame = frame
        self.safeAreaTopInset = safeAreaTopInset
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
    }

    init(screen: NSScreen) {
        self.init(
            frame: screen.frame,
            safeAreaTopInset: screen.safeAreaInsets.top,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea
        )
    }
}

@MainActor
final class NotchLayoutModel: ObservableObject {
    @Published private(set) var metrics: NotchMetrics

    init(screen: NSScreen) {
        metrics = .resolve(for: screen)
    }

    init(geometry: NotchScreenGeometry) {
        metrics = .resolve(for: geometry)
    }

    func update(for screen: NSScreen) {
        update(for: NotchScreenGeometry(screen: screen))
    }

    func update(for geometry: NotchScreenGeometry) {
        let newMetrics = NotchMetrics.resolve(for: geometry)
        if newMetrics != metrics {
            metrics = newMetrics
        }
    }
}
