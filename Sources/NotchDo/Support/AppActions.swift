import AppKit

enum AppActions {
    static let quickCaptureRequested = Notification.Name(
        "com.luku.NotchDo.quickCaptureRequested"
    )

    static func requestQuickCapture() {
        NotificationCenter.default.post(name: quickCaptureRequested, object: nil)
    }

    static func openReminders() {
        #if !NOTCHDO_DEMO
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.reminders"
        ) else { return }
        NSWorkspace.shared.open(url)
        #endif
    }

    static func openRemindersPrivacySettings() {
        #if !NOTCHDO_DEMO
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
        ) else { return }
        NSWorkspace.shared.open(url)
        #endif
    }
}
