import AppKit
import Testing
@testable import NotchDo

@Suite("Notch layout")
struct NotchLayoutTests {
    @Test("Layout model publishes only meaningful geometry changes")
    @MainActor
    func layoutModelUpdates() {
        let initial = NotchScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            safeAreaTopInset: 0,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )
        let model = NotchLayoutModel(geometry: initial)
        let initialMetrics = NotchMetrics.resolve(for: initial)
        #expect(model.metrics == initialMetrics)

        model.update(for: initial)
        #expect(model.metrics == initialMetrics)

        let changed = NotchScreenGeometry(
            frame: CGRect(x: 100, y: 50, width: 1512, height: 982),
            safeAreaTopInset: 38,
            auxiliaryTopLeftArea: CGRect(x: 100, y: 994, width: 640, height: 38),
            auxiliaryTopRightArea: CGRect(x: 872, y: 994, width: 740, height: 38)
        )
        model.update(for: changed)
        #expect(model.metrics == NotchMetrics.resolve(for: changed))
        #expect(model.metrics != initialMetrics)
    }

    @Test("Valid hardware cutout geometry produces notch-aligned metrics")
    func hardwareNotch() {
        let geometry = NotchScreenGeometry(
            frame: CGRect(x: 100, y: 50, width: 1512, height: 982),
            safeAreaTopInset: 38,
            auxiliaryTopLeftArea: CGRect(x: 100, y: 994, width: 640, height: 38),
            auxiliaryTopRightArea: CGRect(x: 872, y: 994, width: 740, height: 38)
        )

        let metrics = NotchMetrics.resolve(for: geometry)

        #expect(metrics.collapsedSize == CGSize(width: 132, height: 38))
        #expect(metrics.expandedSize == CGSize(width: 440, height: 470))
        #expect(metrics.bridgeHeight == 38)
        #expect(metrics.anchorX == 806)
        #expect(metrics.screenTop == 1032)
        #expect(metrics.notchTriggerRect == CGRect(x: 740, y: 994, width: 132, height: 40))
    }

    @Test(
        "Invalid or missing cutouts use centered fallback",
        arguments: [
            NotchScreenGeometry(
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                safeAreaTopInset: 0,
                auxiliaryTopLeftArea: nil,
                auxiliaryTopRightArea: nil
            ),
            NotchScreenGeometry(
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                safeAreaTopInset: 30,
                auxiliaryTopLeftArea: CGRect(x: 0, y: 870, width: 700, height: 30),
                auxiliaryTopRightArea: CGRect(x: 760, y: 870, width: 680, height: 30)
            ),
            NotchScreenGeometry(
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                safeAreaTopInset: 30,
                auxiliaryTopLeftArea: CGRect(x: 0, y: 870, width: 500, height: 30),
                auxiliaryTopRightArea: CGRect(x: 910, y: 870, width: 530, height: 30)
            )
        ]
    )
    func fallback(geometry: NotchScreenGeometry) {
        let metrics = NotchMetrics.resolve(for: geometry)
        #expect(metrics.collapsedSize == CGSize(width: 214, height: 34))
        #expect(metrics.bridgeHeight == 34)
        #expect(metrics.anchorX == 720)
        #expect(metrics.screenTop == 900)
        #expect(metrics.notchTriggerRect == CGRect(x: 613, y: 866, width: 214, height: 36))
    }

    @Test("Fallback respects a safe-area inset taller than the default")
    func tallFallback() {
        let metrics = NotchMetrics.resolve(
            for: NotchScreenGeometry(
                frame: CGRect(x: 50, y: 100, width: 1200, height: 800),
                safeAreaTopInset: 44,
                auxiliaryTopLeftArea: nil,
                auxiliaryTopRightArea: nil
            )
        )
        #expect(metrics.collapsedSize == CGSize(width: 214, height: 44))
        #expect(metrics.bridgeHeight == 44)
        #expect(metrics.anchorX == 650)
        #expect(metrics.notchTriggerRect == CGRect(x: 543, y: 856, width: 214, height: 46))
    }
}
