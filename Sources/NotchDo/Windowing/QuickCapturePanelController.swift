import AppKit
import SwiftUI

@MainActor
final class QuickCapturePanelController: NSObject {
    private let store: RemindersStore
    private let session: QuickCaptureSession
    private var panel: QuickCapturePanel?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var previouslyActiveApplication: NSRunningApplication?

    init(store: RemindersStore) {
        self.store = store
        session = QuickCaptureSession(store: store)
        super.init()
        configurePanel()
        NotificationCenter.default.addObserver(
            self, selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification, object: nil
        )
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
        guard !panel.isVisible else {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        previouslyActiveApplication = NSWorkspace.shared.frontmostApplication
        session.prepare()
        position(panel, on: Self.activeScreen())
        installOutsideClickMonitor()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        Task { await store.refreshAuthorization() }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func dismiss(restorePreviousApplication: Bool = true) {
        guard let panel, panel.isVisible else { return }
        removeOutsideClickMonitor()
        panel.orderOut(nil)
        if restorePreviousApplication, NSApp.isActive,
           previouslyActiveApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previouslyActiveApplication?.activate()
        }
        previouslyActiveApplication = nil
    }

    private func configurePanel() {
        let panel = QuickCapturePanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: 660, height: 150)),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // SwiftUI owns the surface; the window draws no background or shadow.
        panel.hasShadow = false
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

        // A borderless floating panel is required on macOS 14. SwiftUI owns
        // the material, shape, layout, controls, and popovers inside it.
        let rootView = QuickCaptureView(
            store: store,
            session: session,
            onDismiss: { [weak self] in self?.dismiss() },
            onHeightChange: { [weak self] height in
                guard let panel = self?.panel, abs(panel.frame.height - height) > 0.5 else { return }
                var frame = panel.frame
                frame.origin.y += frame.height - height
                frame.size.height = height
                panel.setFrame(frame, display: true)
            }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
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
            Task { @MainActor in self?.dismiss(restorePreviousApplication: false) }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            // Clicks in our popovers belong to capture. Other app windows do not.
            if let window = event.window,
               window is NotchPanel || !(window is NSPanel) {
                self?.dismiss(restorePreviousApplication: false)
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    private static func activeScreen() -> NSScreen {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    @objc private func applicationDidResignActive() {
        dismiss(restorePreviousApplication: false)
    }
}
