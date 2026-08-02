import AppKit

final class ScrollActivityDetectorCoordinator: NSObject {
    var expandedRowIndex: Int?
    var onScroll: () -> Void
    var onOutsideClick: () -> Void
    var onEscape: () -> Void

    private weak var scrollView: NSScrollView?
    private weak var tableView: NSTableView?
    private var eventMonitor: Any?

    init(
        expandedRowIndex: Int?,
        onScroll: @escaping () -> Void,
        onOutsideClick: @escaping () -> Void,
        onEscape: @escaping () -> Void
    ) {
        self.expandedRowIndex = expandedRowIndex
        self.onScroll = onScroll
        self.onOutsideClick = onOutsideClick
        self.onEscape = onEscape
        super.init()

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel, .leftMouseDown, .keyDown]
        ) {
            [weak self] event in
            self?.handle(event) ?? event
        }
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    func attach(to view: NSView) {
        guard scrollView == nil else { return }

        var ancestor: NSView? = view
        while let candidate = ancestor {
            if let scrollView = candidate as? NSScrollView {
                attach(to: scrollView)
                return
            }
            if let scrollView = candidate.listScrollViewDescendant() {
                attach(to: scrollView)
                return
            }
            ancestor = candidate.superview
        }

        DispatchQueue.main.async { [weak self, weak view] in
            guard let self, let view else { return }
            self.attach(to: view)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let scrollView,
              event.window === scrollView.window else { return event }

        switch event.type {
        case .scrollWheel:
            let location = scrollView.convert(event.locationInWindow, from: nil)
            guard scrollView.bounds.contains(location) else { return event }
            guard abs(event.scrollingDeltaX) > 0
                || abs(event.scrollingDeltaY) > 0 else { return event }
            onScroll()
        case .leftMouseDown:
            guard let expandedRowIndex,
                  !isInsideRow(expandedRowIndex, event: event) else { return event }
            onOutsideClick()
        case .keyDown:
            guard event.keyCode == 53,
                  expandedRowIndex != nil else { return event }
            onEscape()
            return nil
        default:
            break
        }
        return event
    }

    private func attach(to scrollView: NSScrollView) {
        self.scrollView = scrollView
        tableView = scrollView.containedTableView
    }

    private func isInsideRow(_ row: Int, event: NSEvent) -> Bool {
        guard let tableView else { return false }
        let location = tableView.convert(event.locationInWindow, from: nil)
        guard row >= 0, row < tableView.numberOfRows else { return false }

        // ReminderRow draws its card inside three points of vertical spacing;
        // the final row also owns fourteen points of scroll breathing room.
        var cardRect = tableView.rect(ofRow: row).insetBy(dx: 0, dy: 3)
        if row == tableView.numberOfRows - 1 {
            cardRect.size.height = max(cardRect.height - 14, 0)
        }
        return cardRect.contains(location)
    }
}

private extension NSView {
    func listScrollViewDescendant() -> NSScrollView? {
        if let scrollView = self as? NSScrollView,
           scrollView.containsTableView {
            return scrollView
        }

        for subview in subviews {
            if let match = subview.listScrollViewDescendant() {
                return match
            }
        }
        return nil
    }
}

private extension NSScrollView {
    var containsTableView: Bool {
        guard let documentView else { return false }
        if documentView is NSTableView { return true }
        return documentView.descendantsContainTableView
    }

    var containedTableView: NSTableView? {
        if let tableView = documentView as? NSTableView {
            return tableView
        }
        return documentView?.firstTableViewDescendant
    }
}

private extension NSView {
    var firstTableViewDescendant: NSTableView? {
        if let tableView = self as? NSTableView { return tableView }
        for subview in subviews {
            if let match = subview.firstTableViewDescendant {
                return match
            }
        }
        return nil
    }

    var descendantsContainTableView: Bool {
        for subview in subviews {
            if subview is NSTableView || subview.descendantsContainTableView {
                return true
            }
        }
        return false
    }
}
