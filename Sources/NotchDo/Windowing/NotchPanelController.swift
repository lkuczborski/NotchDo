import AppKit
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
    private let store: RemindersStore
    private let layout: NotchLayoutModel
    private let interaction = NotchInteractionModel()
    private var anchorScreen: NSScreen
    private var panel: NotchPanel?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var pointerPollingTimer: Timer?

    init(store: RemindersStore) {
        let screen = Self.preferredScreen()
        self.store = store
        self.layout = NotchLayoutModel(screen: screen)
        self.anchorScreen = screen
        super.init()
        interaction.onExpansionChange = { [weak self] expanded in
            self?.setExpanded(expanded)
        }
        configurePanel()
        installPointerMonitoring()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    func show() {
        panel?.orderFrontRegardless()
        updatePointerLocation()
    }

    private func configurePanel() {
        // Keep the WindowServer surface fixed. Only the SwiftUI mask animates,
        // so Core Animation can pace the transition for the active display.
        let frame = frame(for: layout.metrics.expandedSize)
        let panel = NotchPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let rootView = NotchRootView(store: store, layout: layout, interaction: interaction)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        panel.contentView = hostingView

        self.panel = panel
    }

    private func installPointerMonitoring() {
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDown,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in
                self?.updatePointerLocation()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.updatePointerLocation()
            return event
        }

        // Mouse monitors normally trigger expansion immediately. This low-cost
        // fallback only samples the hardware cutout, where macOS can omit an
        // event; it never drives or clocks the SwiftUI animation.
        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(pointerPollingTick),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 1.0 / 120.0
        RunLoop.main.add(timer, forMode: .common)
        pointerPollingTimer = timer
    }

    private func updatePointerLocation() {
        guard let panel else { return }
        let pointer = NSEvent.mouseLocation
        let activeRect = interaction.isExpanded
            ? panel.frame.insetBy(dx: -3, dy: -3)
            : layout.metrics.notchTriggerRect
        interaction.updatePointerInside(activeRect.contains(pointer))
    }

    @objc
    private func pointerPollingTick() {
        updatePointerLocation()
    }

    private func setExpanded(_ expanded: Bool) {
        guard let panel else { return }
        if expanded {
            panel.ignoresMouseEvents = false
            panel.makeKey()
        } else {
            panel.ignoresMouseEvents = true
            panel.resignKey()
        }
    }

    private func frame(for size: CGSize) -> CGRect {
        let metrics = layout.metrics
        return CGRect(
            x: metrics.anchorX - size.width / 2,
            y: metrics.screenTop - size.height,
            width: size.width,
            height: size.height
        )
    }

    private static func preferredScreen() -> NSScreen {
        if let notchedScreen = NSScreen.screens.first(where: {
            $0.safeAreaInsets.top > 0
                && $0.auxiliaryTopLeftArea != nil
                && $0.auxiliaryTopRightArea != nil
        }) {
            return notchedScreen
        }

        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    @objc
    private func screenParametersDidChange() {
        guard let panel else { return }
        anchorScreen = Self.preferredScreen()
        layout.update(for: anchorScreen)
        panel.setFrame(frame(for: layout.metrics.expandedSize), display: true)
        updatePointerLocation()
    }

    @objc
    private func applicationWillTerminate() {
        pointerPollingTimer?.invalidate()
        pointerPollingTimer = nil
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }
}

private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
