import Foundation
import Testing
@testable import NotchDo

@Suite("Launch at Login", .serialized)
@MainActor
struct LaunchAtLoginStoreTests {
    @Test("Registration updates the visible state")
    func registrationSucceeds() {
        let service = FakeLoginItemService(state: .notRegistered)
        let store = LaunchAtLoginStore(service: service)

        store.setRequested(true)

        #expect(store.state == .enabled)
        #expect(store.isRequested)
        #expect(store.errorMessage == nil)
        #expect(service.registerCallCount == 1)
    }

    @Test("Registration failure rolls the toggle back and reports the error")
    func registrationFails() {
        let service = FakeLoginItemService(state: .notRegistered)
        service.registerError = testError
        let store = LaunchAtLoginStore(service: service)

        store.setRequested(true)

        #expect(store.state == .notRegistered)
        #expect(!store.isRequested)
        #expect(store.errorMessage?.contains("permission was denied") == true)
    }

    @Test("Unregistration failure preserves the enabled state")
    func unregistrationFails() {
        let service = FakeLoginItemService(state: .enabled)
        service.unregisterError = testError
        let store = LaunchAtLoginStore(service: service)

        store.setRequested(false)

        #expect(store.state == .enabled)
        #expect(store.isRequested)
        #expect(store.errorMessage?.contains("couldn’t disable") == true)
    }

    @Test("Approval-required registration remains requested")
    func registrationRequiresApproval() {
        let service = FakeLoginItemService(state: .notRegistered)
        service.registerError = testError
        service.registrationFailureState = .requiresApproval
        let store = LaunchAtLoginStore(service: service)

        store.setRequested(true)

        #expect(store.state == .requiresApproval)
        #expect(store.isRequested)
        #expect(store.state.detail.contains("Approval is required"))
        #expect(store.errorMessage == nil)
    }

    @Test("Refresh reflects changes made in System Settings")
    func refreshesExternalState() {
        let service = FakeLoginItemService(state: .notRegistered)
        let store = LaunchAtLoginStore(service: service)
        service.state = .enabled

        store.refresh()

        #expect(store.state == .enabled)
    }

    private var testError: NSError {
        NSError(
            domain: "LaunchAtLoginStoreTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "permission was denied"]
        )
    }
}
