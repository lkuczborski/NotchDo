@MainActor
protocol LoginItemService {
    var state: LaunchAtLoginState { get }

    func register() throws
    func unregister() throws
    func openSystemSettings()
}
