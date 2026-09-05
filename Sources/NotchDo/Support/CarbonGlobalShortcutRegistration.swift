import Carbon.HIToolbox
import Foundation

@MainActor
final class CarbonGlobalShortcutRegistration: GlobalShortcutRegistration {
    private static let hotKeyID = EventHotKeyID(signature: 0x4E_44_51_43, id: 1) // NDQC
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (@MainActor () -> Void)?
    private var pressState = GlobalShortcutPressState()

    init() {
        var eventTypes = [EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        ), EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyReleased)
        )]
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
                let isPressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                Task { @MainActor in
                    if registration.pressState.update(isPressed: isPressed) {
                        registration.action?()
                    }
                }
                return noErr
            },
            2,
            &eventTypes,
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
        pressState = GlobalShortcutPressState()
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
