import Foundation
import Observation

@MainActor
@Observable
final class GlobalShortcutStore {
    static let defaultsKey = "notchdo.globalQuickCaptureShortcut"

    private(set) var shortcut: GlobalShortcut
    private(set) var registrationError: String?
    var onPerformShortcut: (@MainActor () -> Void)?

    private let registration: any GlobalShortcutRegistration
    private let userDefaults: UserDefaults?

    init() {
        registration = CarbonGlobalShortcutRegistration()
        userDefaults = .standard
        shortcut = Self.loadShortcut(from: .standard)
        _ = registerCurrentShortcut()
    }

    init(
        registration: any GlobalShortcutRegistration,
        userDefaults: UserDefaults?
    ) {
        self.registration = registration
        self.userDefaults = userDefaults
        shortcut = Self.loadShortcut(from: userDefaults)
        _ = registerCurrentShortcut()
    }

    @discardableResult
    func setShortcut(_ candidate: GlobalShortcut) -> Bool {
        guard candidate.isValid else {
            registrationError = "Include at least one modifier and a letter, number, Space, or function key."
            return false
        }

        let previous = shortcut
        shortcut = candidate
        guard registerCurrentShortcut() else {
            shortcut = previous
            _ = registerCurrentShortcut()
            registrationError = "That shortcut is already used by another app."
            return false
        }

        if let data = try? JSONEncoder().encode(candidate) {
            userDefaults?.set(data, forKey: Self.defaultsKey)
        }
        return true
    }

    func beginRecording() {
        registration.unregister()
    }

    func endRecording() {
        _ = registerCurrentShortcut()
    }

    private func registerCurrentShortcut() -> Bool {
        let didRegister = registration.register(shortcut) { [weak self] in
            self?.onPerformShortcut?()
        }
        registrationError = didRegister ? nil : "That shortcut is already used by another app."
        return didRegister
    }

    private static func loadShortcut(from userDefaults: UserDefaults?) -> GlobalShortcut {
        guard let data = userDefaults?.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(GlobalShortcut.self, from: data),
              decoded.isValid else { return .default }
        return decoded
    }
}
