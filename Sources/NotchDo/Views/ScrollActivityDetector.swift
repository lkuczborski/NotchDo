import AppKit
import SwiftUI

/// A narrow bridge for scroll-wheel activity and empty-space clicks that
/// SwiftUI's macOS `List` does not expose. SwiftUI remains the source of truth.
struct ScrollActivityDetector: NSViewRepresentable {
    let expandedRowIndex: Int?
    let onScroll: () -> Void
    let onOutsideClick: () -> Void
    let onEscape: () -> Void

    func makeCoordinator() -> ScrollActivityDetectorCoordinator {
        ScrollActivityDetectorCoordinator(
            expandedRowIndex: expandedRowIndex,
            onScroll: onScroll,
            onOutsideClick: onOutsideClick,
            onEscape: onEscape
        )
    }

    func makeNSView(context: Context) -> ScrollActivityDetectorView {
        let view = ScrollActivityDetectorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ScrollActivityDetectorView, context: Context) {
        context.coordinator.expandedRowIndex = expandedRowIndex
        context.coordinator.onScroll = onScroll
        context.coordinator.onOutsideClick = onOutsideClick
        context.coordinator.onEscape = onEscape
        context.coordinator.attach(to: nsView)
    }
}
