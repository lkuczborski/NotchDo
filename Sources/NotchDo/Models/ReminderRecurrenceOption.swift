import EventKit

enum ReminderRecurrenceOption: String, CaseIterable, Identifiable {
    case never
    case daily
    case weekly
    case monthly
    case yearly
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    init(rules: [EKRecurrenceRule]?) {
        guard let rules, rules.count == 1, let rule = rules.first else {
            self = rules?.isEmpty == false ? .custom : .never
            return
        }

        switch rule.frequency {
        case .daily: self = .daily
        case .weekly: self = .weekly
        case .monthly: self = .monthly
        case .yearly: self = .yearly
        @unknown default: self = .custom
        }
    }

    var recurrenceRule: EKRecurrenceRule? {
        let frequency: EKRecurrenceFrequency
        switch self {
        case .never, .custom:
            return nil
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .monthly:
            frequency = .monthly
        case .yearly:
            frequency = .yearly
        }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil)
    }
}
