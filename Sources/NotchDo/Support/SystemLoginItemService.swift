import ServiceManagement

@MainActor
struct SystemLoginItemService: LoginItemService {
    var state: LaunchAtLoginState {
        Self.state(for: SMAppService.mainApp.status)
    }

    static func state(for status: SMAppService.Status) -> LaunchAtLoginState {
        switch status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            // macOS can report notFound for an otherwise valid main-app
            // service before its first registration. Keep the preference
            // actionable so register() can establish the login item.
            .notRegistered
        @unknown default:
            .unavailable
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
