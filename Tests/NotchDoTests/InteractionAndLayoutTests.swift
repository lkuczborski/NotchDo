import AppKit
import SwiftUI
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

@Suite("Notch surface shape")
struct NotchSurfaceShapeTests {
    @Test("Radii are clamped to valid geometry")
    func radiusClamping() {
        let oversized = NotchSurfaceShape(topCornerRadius: 100, bottomCornerRadius: 100)
        let radii = oversized.resolvedRadii(in: CGRect(x: 0, y: 0, width: 80, height: 30))
        #expect(radii.top == 15)
        #expect(radii.bottom == 15)

        let negative = NotchSurfaceShape(topCornerRadius: -10, bottomCornerRadius: -20)
        let zeroed = negative.resolvedRadii(in: CGRect(x: 0, y: 0, width: 80, height: 30))
        #expect(zeroed.top == 0)
        #expect(zeroed.bottom == 0)
    }

    @Test("Animatable data round-trips both independent radii")
    func animationData() {
        var shape = NotchSurfaceShape(topCornerRadius: 5, bottomCornerRadius: 12)
        #expect(shape.animatableData.first == 5)
        #expect(shape.animatableData.second == 12)

        shape.animatableData = AnimatablePair(8, 20)
        #expect(shape.topCornerRadius == 8)
        #expect(shape.bottomCornerRadius == 20)
        #expect(shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 60)).boundingRect
            == CGRect(x: 0, y: 0, width: 100, height: 60))
    }
}

@Suite("Task-count frame preference")
struct TaskCountBadgeFrameKeyTests {
    @Test("Empty updates do not erase the most recent measured frame")
    func reduction() {
        var value = CGRect(x: 4, y: 5, width: 22, height: 22)
        TaskCountBadgeFrameKey.reduce(value: &value) { .zero }
        #expect(value == CGRect(x: 4, y: 5, width: 22, height: 22))

        let replacement = CGRect(x: 10, y: 11, width: 22, height: 22)
        TaskCountBadgeFrameKey.reduce(value: &value) { replacement }
        #expect(value == replacement)
        #expect(TaskCountBadgeFrameKey.defaultValue == .zero)
    }
}
