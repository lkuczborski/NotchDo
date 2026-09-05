@testable import NotchDo

@MainActor
final class FakeGlobalShortcutRegistration: GlobalShortcutRegistration {
    var shouldRegister = true
    var rejectedShortcuts: [GlobalShortcut] = []
    private(set) var registeredShortcuts: [GlobalShortcut] = []
    private(set) var unregisterCount = 0
    private var action: (@MainActor () -> Void)?

    func register(
        _ shortcut: GlobalShortcut,
        action: @escaping @MainActor () -> Void
    ) -> Bool {
        registeredShortcuts.append(shortcut)
        let succeeds = shouldRegister && !rejectedShortcuts.contains(shortcut)
        self.action = succeeds ? action : nil
        return succeeds
    }

    func unregister() {
        unregisterCount += 1
        action = nil
    }

    func invoke() {
        action?()
    }
}
