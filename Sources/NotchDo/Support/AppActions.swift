import AppKit

enum AppActions {
    static func openReminders() {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.reminders"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    static func openRemindersPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
