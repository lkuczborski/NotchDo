import AppKit
import SwiftUI

@MainActor
final class QuickCapturePanelController: NSObject {
    private let store: RemindersStore
    private let session: QuickCaptureSession
    private var panel: QuickCapturePanel?
    private var outsideClickMonitor: Any?
    private weak var previouslyActiveApplication: NSRunningApplication?

    init(store: RemindersStore) {
        self.store = store
        session = QuickCaptureSession(store: store)
        super.init()
        configurePanel()
    }

    func toggle() {
        if panel?.isVisible == true {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        guard let panel else { return }
        previouslyActiveApplication = NSWorkspace.shared.frontmostApplication
        session.prepare()
        position(panel, on: Self.activeScreen())
        installOutsideClickMonitor()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func dismiss() {
        guard let panel, panel.isVisible else { return }
        removeOutsideClickMonitor()
        panel.orderOut(nil)
        previouslyActiveApplication?.activate()
        previouslyActiveApplication = nil
    }

    private func configurePanel() {
        let panel = QuickCapturePanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: 660, height: 220)),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .moveToActiveSpace,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.title = "Quick Reminder"
        panel.setAccessibilityTitle("Quick Reminder")

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 20
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let rootView = QuickCaptureView(
            store: store,
            session: session,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])
        panel.contentView = effectView
        self.panel = panel
    }

    private func position(_ panel: NSPanel, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            QuickCapturePanelPlacement.origin(panelSize: size, visibleFrame: visible)
        )
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private static func activeScreen() -> NSScreen {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
