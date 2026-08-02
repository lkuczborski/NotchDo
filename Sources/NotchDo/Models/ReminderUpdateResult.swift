struct ReminderUpdateResult: Equatable {
    let succeeded: Bool
    let rejectedFields: Set<ReminderEditField>

    static let saved = ReminderUpdateResult(succeeded: true, rejectedFields: [])
    static let failed = ReminderUpdateResult(succeeded: false, rejectedFields: [])

    static func saved(rejecting fields: Set<ReminderEditField>) -> Self {
        ReminderUpdateResult(succeeded: true, rejectedFields: fields)
    }
}
