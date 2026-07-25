enum ReminderSyncState: Equatable {
    case idle
    case syncing
    case synced
    case failed(String)
}
