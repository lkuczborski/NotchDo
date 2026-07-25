import AppKit

final class ScrollActivityDetectorView: NSView {
    weak var coordinator: ScrollActivityDetectorCoordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: self)
    }
}
