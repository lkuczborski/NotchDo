import Observation

@MainActor
@Observable
final class LaunchAtLoginStore {
    private let service: any LoginItemService

    private(set) var state: LaunchAtLoginState
    private(set) var errorMessage: String?

    init() {
        let service = SystemLoginItemService()
        self.service = service
        self.state = service.state
    }

    init(service: any LoginItemService) {
        self.service = service
        self.state = service.state
    }

    var isRequested: Bool {
        state.isRequested
    }

    func refresh() {
        state = service.state
    }

    func setRequested(_ requested: Bool) {
        errorMessage = nil

        do {
            if requested {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            refresh()
            guard isRequested != requested else { return }

            errorMessage = requested
                ? "NotchDo couldn’t enable Launch at Login: \(error.localizedDescription)"
                : "NotchDo couldn’t disable Launch at Login: \(error.localizedDescription)"
        }

        refresh()
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}
