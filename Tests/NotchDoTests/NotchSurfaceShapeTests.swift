import SwiftUI
import Testing
@testable import NotchDo

@Suite("Notch surface shape")
struct NotchSurfaceShapeTests {
    @Test("Radii are clamped to valid geometry")
    func radiusClamping() {
        let oversized = NotchSurfaceShape(topCornerRadius: 100, bottomCornerRadius: 100)
        let radii = oversized.resolvedRadii(
            in: CGRect(x: 0, y: 0, width: 80, height: 30)
        )
        #expect(radii.top == 15)
        #expect(radii.bottom == 15)

        let negative = NotchSurfaceShape(topCornerRadius: -10, bottomCornerRadius: -20)
        let zeroed = negative.resolvedRadii(
            in: CGRect(x: 0, y: 0, width: 80, height: 30)
        )
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
