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
