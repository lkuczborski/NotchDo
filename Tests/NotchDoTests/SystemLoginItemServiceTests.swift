import ServiceManagement
import Testing
@testable import NotchDo

@Suite("System login item status")
@MainActor
struct SystemLoginItemServiceTests {
    @Test(
        "ServiceManagement statuses remain actionable",
        arguments: [
            (SMAppService.Status.notRegistered, LaunchAtLoginState.notRegistered),
            (SMAppService.Status.enabled, LaunchAtLoginState.enabled),
            (SMAppService.Status.requiresApproval, LaunchAtLoginState.requiresApproval),
            (SMAppService.Status.notFound, LaunchAtLoginState.notRegistered)
        ]
    )
    func mapsStatus(status: SMAppService.Status, expected: LaunchAtLoginState) {
        #expect(SystemLoginItemService.state(for: status) == expected)
    }
}
