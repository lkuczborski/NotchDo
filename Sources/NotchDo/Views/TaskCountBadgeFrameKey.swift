import SwiftUI

struct TaskCountBadgeFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextFrame = nextValue()
        if !nextFrame.isEmpty {
            value = nextFrame
        }
    }
}
