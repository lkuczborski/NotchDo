import SwiftUI

struct QuickCaptureSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    func body(content: Content) -> some View {
        surface(content: content)
            .overlay {
                shape.strokeBorder(
                    colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.07),
                    lineWidth: 0.5
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 8, y: 3)
    }

    @ViewBuilder
    private func surface(content: Content) -> some View {
        if reduceTransparency {
            content.background(.background, in: shape)
        } else if #available(macOS 26, *) {
            // Regular glass adapts contrast over arbitrary windows. Clear glass
            // lacks that adaptation and makes text illegible over dark content.
            content.glassEffect(.regular, in: shape)
                .clipShape(shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}
