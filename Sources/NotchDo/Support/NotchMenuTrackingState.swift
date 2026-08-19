struct NotchMenuTrackingState {
    private(set) var depth = 0

    var isTracking: Bool {
        depth > 0
    }

    mutating func beginTracking() -> Bool {
        let becameActive = depth == 0
        depth += 1
        return becameActive
    }

    mutating func endTracking() -> Bool {
        guard depth > 0 else { return false }
        depth -= 1
        return depth == 0
    }

    mutating func reset() -> Bool {
        guard depth > 0 else { return false }
        depth = 0
        return true
    }
}
