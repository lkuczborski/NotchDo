import Carbon.HIToolbox
import Foundation

@MainActor
final class CarbonGlobalShortcutRegistration: GlobalShortcutRegistration {
    private static let hotKeyID = EventHotKeyID(signature: 0x4E_44_51_43, id: 1) // NDQC
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (@MainActor () -> Void)?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr,
                      identifier.signature == CarbonGlobalShortcutRegistration.hotKeyID.signature,
                      identifier.id == CarbonGlobalShortcutRegistration.hotKeyID.id else {
                    return OSStatus(eventNotHandledErr)
                }
                let registration = Unmanaged<CarbonGlobalShortcutRegistration>
                    .fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in registration.action?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func register(
        _ shortcut: GlobalShortcut,
        action: @escaping @MainActor () -> Void
    ) -> Bool {
        unregister()
        guard eventHandler != nil else { return false }
        self.action = action
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            CarbonGlobalShortcutRegistration.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status != noErr {
            self.action = nil
            hotKey = nil
        }
        return status == noErr
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        action = nil
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
