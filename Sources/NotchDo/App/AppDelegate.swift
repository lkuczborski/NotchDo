import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let remindersStore = RemindersStore()
    let globalShortcutStore = GlobalShortcutStore()
    private var panelController: NotchPanelController?
    private var quickCapturePanelController: QuickCapturePanelController?
    private var quickCaptureRequestObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = NotchPanelController(store: remindersStore)
        self.panelController = panelController
        panelController.show()

        let quickCapturePanelController = QuickCapturePanelController(store: remindersStore)
        self.quickCapturePanelController = quickCapturePanelController
        globalShortcutStore.onPerformShortcut = { [weak quickCapturePanelController] in
            quickCapturePanelController?.toggle()
        }
        quickCaptureRequestObserver = NotificationCenter.default.addObserver(
            forName: AppActions.quickCaptureRequested,
            object: nil,
            queue: .main
        ) { [weak quickCapturePanelController] _ in
            Task { @MainActor in quickCapturePanelController?.show() }
        }

        Task {
            await remindersStore.start()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task {
            await remindersStore.refreshAuthorization()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let quickCaptureRequestObserver {
            NotificationCenter.default.removeObserver(quickCaptureRequestObserver)
        }
    }
}
