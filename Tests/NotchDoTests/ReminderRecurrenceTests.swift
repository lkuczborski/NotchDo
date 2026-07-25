import EventKit
import Testing
@testable import NotchDo

@Suite("Reminder recurrence")
struct ReminderRecurrenceTests {
    @Test("No rules means never; ambiguous rules remain custom")
    func absentAndAmbiguousRules() {
        #expect(ReminderRecurrenceOption(rules: nil) == .never)
        #expect(ReminderRecurrenceOption(rules: []) == .never)

        let daily = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
        )
        let weekly = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        )
        #expect(ReminderRecurrenceOption(rules: [daily, weekly]) == .custom)
    }

    @Test(
        "A single supported rule maps by frequency",
        arguments: [
            (EKRecurrenceFrequency.daily, ReminderRecurrenceOption.daily),
            (.weekly, .weekly),
            (.monthly, .monthly),
            (.yearly, .yearly)
        ]
    )
    func supportedRule(
        frequency: EKRecurrenceFrequency,
        expected: ReminderRecurrenceOption
    ) {
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: 2,
            end: nil
        )
        #expect(ReminderRecurrenceOption(rules: [rule]) == expected)
    }

    @Test("Editable options create one-interval EventKit rules")
    func recurrenceRuleCreation() {
        for option in [
            ReminderRecurrenceOption.daily,
            .weekly,
            .monthly,
            .yearly
        ] {
            let rule = option.recurrenceRule
            #expect(rule != nil)
            #expect(rule?.interval == 1)
            #expect(ReminderRecurrenceOption(rules: rule.map { [$0] }) == option)
        }
        #expect(ReminderRecurrenceOption.never.recurrenceRule == nil)
        #expect(ReminderRecurrenceOption.custom.recurrenceRule == nil)
    }

    @Test("Titles and identifiers are stable")
    func titlesAndIdentifiers() {
        #expect(ReminderRecurrenceOption.allCases.map(\.title) == [
            "Never", "Daily", "Weekly", "Monthly", "Yearly", "Custom"
        ])
        #expect(ReminderRecurrenceOption.allCases.map(\.id) == [
            "never", "daily", "weekly", "monthly", "yearly", "custom"
        ])
    }
}
