import SwiftUI

// Path geometry adapted from DynamicNotchKit's NotchShape by Kai Azim.
// Used under the MIT License; see THIRD_PARTY_NOTICES.md.
/// A simple notch silhouette whose corner geometry remains explicit and
/// continuously animatable as the visible surface changes size.
struct NotchSurfaceShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let radii = resolvedRadii(in: rect)
        let topRadius = radii.top
        let bottomRadius = radii.bottom

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control: CGPoint(x: rect.minX + topRadius, y: rect.minY)
        )
        path.addLine(
            to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius)
        )
        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topRadius + bottomRadius,
                y: rect.maxY
            ),
            control: CGPoint(x: rect.minX + topRadius, y: rect.maxY)
        )
        path.addLine(
            to: CGPoint(
                x: rect.maxX - topRadius - bottomRadius,
                y: rect.maxY
            )
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.maxY)
        )
        path.addLine(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }

    func resolvedRadii(in rect: CGRect) -> (top: CGFloat, bottom: CGFloat) {
        let top = min(
            max(0, topCornerRadius),
            rect.width / 4,
            rect.height / 2
        )
        let bottom = min(
            max(0, bottomCornerRadius),
            max(0, rect.width / 2 - top),
            rect.height / 2
        )
        return (top, bottom)
    }
}
