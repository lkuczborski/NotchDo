enum ReminderAuthorizationState: Equatable {
    case notDetermined
    case requesting
    case fullAccess
    case denied
    case restricted
}

enum ReminderSyncState: Equatable {
    case idle
    case syncing
    case synced
    case failed(String)
}
