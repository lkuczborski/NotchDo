import Foundation

enum ReminderDueMode: String, Equatable {
    case none
    case dateOnly
    case dateAndTime

    init(components: DateComponents?) {
        guard let components else {
            self = .none
            return
        }
        let hasDate = components.year != nil || components.month != nil || components.day != nil
        let hasTime = components.hour != nil || components.minute != nil
        switch (hasDate, hasTime) {
        case (true, true): self = .dateAndTime
        case (true, false): self = .dateOnly
        case (false, true): self = .dateAndTime
        case (false, false): self = .none
        }
    }

    var hasDate: Bool {
        self == .dateOnly || self == .dateAndTime
    }

    var hasTime: Bool {
        self == .dateAndTime
    }
}
