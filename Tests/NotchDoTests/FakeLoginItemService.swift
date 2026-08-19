@testable import NotchDo

@MainActor
final class FakeLoginItemService: LoginItemService {
    var state: LaunchAtLoginState
    var registrationResult: LaunchAtLoginState = .enabled
    var registrationFailureState: LaunchAtLoginState?
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            if let registrationFailureState {
                state = registrationFailureState
            }
            throw registerError
        }
        state = registrationResult
    }

    func unregister() throws {
        if let unregisterError {
            throw unregisterError
        }
        state = .notRegistered
    }

    func openSystemSettings() {}
}
