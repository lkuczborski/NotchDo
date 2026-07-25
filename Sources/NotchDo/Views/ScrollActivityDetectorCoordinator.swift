import AppKit

final class ScrollActivityDetectorCoordinator: NSObject {
    var onScroll: () -> Void
    var onBackgroundClick: () -> Void

    private weak var scrollView: NSScrollView?
    private var eventMonitor: Any?

    init(
        onScroll: @escaping () -> Void,
        onBackgroundClick: @escaping () -> Void
    ) {
        self.onScroll = onScroll
        self.onBackgroundClick = onBackgroundClick
        super.init()

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel, .leftMouseDown]
        ) {
            [weak self] event in
            self?.handle(event)
            return event
        }
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    func attach(to view: NSView) {
        guard scrollView == nil else { return }

        var ancestor = view.superview
        while let candidate = ancestor {
            if let scrollView = candidate as? NSScrollView {
                self.scrollView = scrollView
                return
            }
            ancestor = candidate.superview
        }

        DispatchQueue.main.async { [weak self, weak view] in
            guard let self, let view else { return }
            self.attach(to: view)
        }
    }

    private func handle(_ event: NSEvent) {
        guard let scrollView,
              event.window === scrollView.window else { return }

        let location = scrollView.convert(event.locationInWindow, from: nil)
        guard scrollView.bounds.contains(location) else { return }

        switch event.type {
        case .scrollWheel:
            guard abs(event.scrollingDeltaX) > 0
                || abs(event.scrollingDeltaY) > 0 else { return }
            onScroll()
        case .leftMouseDown:
            guard !isInsideListRow(at: location, in: scrollView) else { return }
            onBackgroundClick()
        default:
            break
        }
    }

    private func isInsideListRow(
        at location: NSPoint,
        in scrollView: NSScrollView
    ) -> Bool {
        var candidate = scrollView.hitTest(location)
        while let view = candidate, view !== scrollView {
            if view is NSTableRowView {
                return true
            }
            candidate = view.superview
        }
        return false
    }
}
