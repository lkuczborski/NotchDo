#if NOTCHDO_DEMO
@MainActor
final class DemoLoginItemService: LoginItemService {
    var state: LaunchAtLoginState = .notRegistered
    func register() throws { state = .enabled }
    func unregister() throws { state = .notRegistered }
    func openSystemSettings() {}
}
#endif
