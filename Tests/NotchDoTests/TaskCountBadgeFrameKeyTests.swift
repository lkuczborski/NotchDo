import SwiftUI
import Testing
@testable import NotchDo

@Suite("Task-count frame preference")
struct TaskCountBadgeFrameKeyTests {
    @Test("Empty updates do not erase the most recent measured frame")
    func reduction() {
        var value = CGRect(x: 4, y: 5, width: 22, height: 22)
        TaskCountBadgeFrameKey.reduce(value: &value) { .zero }
        #expect(value == CGRect(x: 4, y: 5, width: 22, height: 22))

        let replacement = CGRect(x: 10, y: 11, width: 22, height: 22)
        TaskCountBadgeFrameKey.reduce(value: &value) { replacement }
        #expect(value == replacement)
        #expect(TaskCountBadgeFrameKey.defaultValue == .zero)
    }
}
