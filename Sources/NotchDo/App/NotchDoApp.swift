import SwiftUI

@main
struct NotchDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                store: appDelegate.remindersStore,
                globalShortcut: appDelegate.globalShortcutStore
            )
        }
        .commands {
            CommandMenu("Capture") {
                Button("Quick Reminder…", action: AppActions.requestQuickCapture)
            }
        }
    }
}
