import AppKit
import SwiftUI

@main
struct NotchDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.remindersStore)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let remindersStore = RemindersStore()
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = NotchPanelController(store: remindersStore)
        self.panelController = panelController
        panelController.show()

        Task {
            await remindersStore.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
