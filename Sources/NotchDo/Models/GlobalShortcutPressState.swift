/// Emits one activation per physical press, ignoring repeats until release.
struct GlobalShortcutPressState {
    private var isDown = false

    mutating func update(isPressed: Bool) -> Bool {
        let shouldActivate = isPressed && !isDown
        isDown = isPressed
        return shouldActivate
    }
}
