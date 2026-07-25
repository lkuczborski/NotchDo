import Testing
@testable import NotchDo

@Suite("Reminder priority")
struct ReminderPriorityTests {
    @Test(
        "EventKit priorities map to editor buckets",
        arguments: [
            (0, ReminderPriorityOption.none),
            (1, .high),
            (4, .high),
            (5, .medium),
            (6, .low),
            (9, .low),
            (10, .none)
        ]
    )
    func mapping(priority: Int, expected: ReminderPriorityOption) {
        #expect(ReminderPriorityOption(priority: priority) == expected)
    }

    @Test("Options preserve EventKit values and user-facing labels")
    func valuesAndTitles() {
        #expect(ReminderPriorityOption.allCases.map(\.rawValue) == [0, 9, 5, 1])
        #expect(ReminderPriorityOption.allCases.map(\.title) == ["None", "Low", "Medium", "High"])
        #expect(ReminderPriorityOption.allCases.map(\.id) == [0, 9, 5, 1])
    }
}
