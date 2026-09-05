import Foundation

@MainActor
protocol GlobalShortcutRegistration: AnyObject {
    func register(_ shortcut: GlobalShortcut, action: @escaping @MainActor () -> Void) -> Bool
    func unregister()
}
