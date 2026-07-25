import AppKit
import SwiftUI

/// A narrow bridge for the scroll-wheel events SwiftUI's macOS `List` does not
/// expose. SwiftUI remains the source of truth for which reminder is expanded.
struct ScrollActivityDetector: NSViewRepresentable {
    let onScroll: () -> Void
    let onBackgroundClick: () -> Void

    func makeCoordinator() -> ScrollActivityDetectorCoordinator {
        ScrollActivityDetectorCoordinator(
            onScroll: onScroll,
            onBackgroundClick: onBackgroundClick
        )
    }

    func makeNSView(context: Context) -> ScrollActivityDetectorView {
        let view = ScrollActivityDetectorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ScrollActivityDetectorView, context: Context) {
        context.coordinator.onScroll = onScroll
        context.coordinator.onBackgroundClick = onBackgroundClick
        context.coordinator.attach(to: nsView)
    }
}
