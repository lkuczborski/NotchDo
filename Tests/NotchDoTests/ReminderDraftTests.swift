import EventKit
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

@Suite("Reminder draft")
struct ReminderDraftTests {
    @Test("Draft captures every editable reminder field")
    func capturesReminder() {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let reminder = events.makeReminder(
            title: "  Keep spacing  ",
            calendar: calendar,
            dueDateComponents: dueComponents(2026, 8, 3, hour: 14, minute: 25)
        )
        reminder.notes = "Notes"
        reminder.priority = 5
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        ]

        let draft = ReminderDraft(reminder: reminder)

        #expect(draft.title == "  Keep spacing  ")
        #expect(draft.notes == "Notes")
        #expect(draft.hasDueDate)
        #expect(draft.dueDate == fixedDate(2026, 8, 3, hour: 14, minute: 25))
        #expect(!draft.isAllDay)
        #expect(draft.priority == .medium)
        #expect(draft.recurrence == .weekly)
    }

    @Test("All-day and absent optional fields use safe defaults")
    func defaults() {
        let events = FakeReminderEventStore()
        let calendar = events.makeCalendar(title: "Inbox")
        let allDay = events.makeReminder(
            title: "",
            calendar: calendar,
            dueDateComponents: dueComponents(2026, 8, 4)
        )
        allDay.title = nil
        allDay.notes = nil

        let allDayDraft = ReminderDraft(reminder: allDay)
        #expect(allDayDraft.title.isEmpty)
        #expect(allDayDraft.notes.isEmpty)
        #expect(allDayDraft.hasDueDate)
        #expect(allDayDraft.isAllDay)
        #expect(allDayDraft.dueDate == fixedDate(2026, 8, 4))
        #expect(allDayDraft.priority == .none)
        #expect(allDayDraft.recurrence == .never)

        let undated = events.makeReminder(title: "Later", calendar: calendar)
        let before = Date()
        let undatedDraft = ReminderDraft(reminder: undated)
        let after = Date()
        #expect(!undatedDraft.hasDueDate)
        #expect(undatedDraft.dueDate >= before.addingTimeInterval(3599))
        #expect(undatedDraft.dueDate <= after.addingTimeInterval(3601))
    }
}
