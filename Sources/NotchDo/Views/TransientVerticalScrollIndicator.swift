import SwiftUI

struct VerticalScrollIndicatorMetrics: Equatable {
    let contentOffset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    var isScrollable: Bool {
        contentHeight > viewportHeight + 1
    }

    func thumbHeight(in trackHeight: CGFloat) -> CGFloat {
        guard contentHeight > 0 else { return trackHeight }
        return min(trackHeight, max(28, trackHeight * viewportHeight / contentHeight))
    }

    func thumbOffset(in trackHeight: CGFloat) -> CGFloat {
        let thumbHeight = thumbHeight(in: trackHeight)
        let scrollRange = max(contentHeight - viewportHeight, 1)
        let progress = min(max(contentOffset / scrollRange, 0), 1)
        return progress * max(trackHeight - thumbHeight, 0)
    }
}

extension View {
    @ViewBuilder
    func transientVerticalScrollIndicator(trigger: Int) -> some View {
        if #available(macOS 15.0, *) {
            modifier(TransientVerticalScrollIndicatorModifier(trigger: trigger))
        } else {
            scrollIndicators(.visible, axes: .vertical)
        }
    }
}

@available(macOS 15.0, *)
private struct TransientVerticalScrollIndicatorModifier: ViewModifier {
    let trigger: Int

    @State private var metrics = VerticalScrollIndicatorMetrics(
        contentOffset: 0,
        contentHeight: 0,
        viewportHeight: 0
    )
    @State private var isScrolling = false
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: VerticalScrollIndicatorMetrics.self) { geometry in
                VerticalScrollIndicatorMetrics(
                    contentOffset: geometry.contentOffset.y + geometry.contentInsets.top,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, newMetrics in
                metrics = newMetrics
            }
            .onChange(of: trigger) { _, _ in
                flashIndicator()
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase.isScrolling {
                    flashIndicator()
                }
            }
            .overlay(alignment: .topTrailing) {
                GeometryReader { geometry in
                    let trackHeight = geometry.size.height
                    let thumbHeight = metrics.isScrollable
                        ? metrics.thumbHeight(in: trackHeight)
                        : min(48, trackHeight)

                    Capsule()
                        .fill(.white.opacity(0.22))
                        .frame(width: 3, height: thumbHeight)
                        .offset(
                            y: metrics.isScrollable
                                ? metrics.thumbOffset(in: trackHeight)
                                : 0
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .opacity(isScrolling ? 1 : 0)
                }
                .padding(.vertical, 2)
                .padding(.trailing, 3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onDisappear {
                hideTask?.cancel()
            }
    }

    private func flashIndicator() {
        hideTask?.cancel()
        withAnimation(.easeOut(duration: 0.08)) {
            isScrolling = true
        }

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isScrolling = false
            }
        }
    }
}
