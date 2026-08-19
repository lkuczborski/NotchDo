import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class RemindersStore: NSObject {
    static let selectedCalendarIdentifierDefaultsKey =
        "notchdo.selectedCalendarIdentifier"

    private(set) var authorization: ReminderAuthorizationState = .notDetermined
    private(set) var syncState: ReminderSyncState = .idle
    private(set) var calendars: [EKCalendar] = []
    private(set) var reminders: [EKReminder] = []
    private(set) var selectedCalendarIdentifier: String?
    private(set) var lastSyncedAt: Date?
    private(set) var lastAddedReminderIdentifier: String?

    private let eventStore: any ReminderEventStore
    private let now: () -> Date
    private let userDefaults: UserDefaults?
    private var reloadGeneration = 0

    override init() {
        eventStore = EKEventStore()
        now = Date.init
        userDefaults = .standard
        super.init()
        observeEventStoreChanges()
    }

    init(
        eventStore: any ReminderEventStore,
        now: @escaping () -> Date = Date.init,
        userDefaults: UserDefaults? = nil
    ) {
        self.eventStore = eventStore
        self.now = now
        self.userDefaults = userDefaults
        super.init()
        observeEventStoreChanges()
    }

    private func observeEventStoreChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreDidChange),
            name: .EKEventStoreChanged,
            object: eventStore.notificationObject
        )
    }

    var selectedCalendar: EKCalendar? {
        calendars.first { $0.calendarIdentifier == selectedCalendarIdentifier }
    }

    var selectedCalendarTitle: String {
        selectedCalendar?.title ?? "Reminders"
    }

    var selectedCalendarIsWritable: Bool {
        guard authorization == .fullAccess, let selectedCalendar else { return false }
        return eventStore.allowsContentModifications(in: selectedCalendar)
    }

    func canModify(_ reminder: EKReminder) -> Bool {
        guard authorization == .fullAccess, let calendar = reminder.calendar else { return false }
        return eventStore.allowsContentModifications(in: calendar)
    }

    func start() async {
        await resolveAuthorization(requestIfNeeded: false)
    }

    func requestAccess() async {
        await resolveAuthorization(requestIfNeeded: true)
    }

    func refreshAuthorization() async {
        await resolveAuthorization(requestIfNeeded: false)
    }

    func reload() async {
        reloadGeneration &+= 1
        let generation = reloadGeneration

        guard authorization == .fullAccess else { return }
        guard let calendar = selectedCalendar else {
            reminders = []
            syncState = .idle
            return
        }

        let calendarIdentifier = calendar.calendarIdentifier
        syncState = .syncing
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let fetched: [EKReminder] = await withCheckedContinuation { continuation in
            _ = eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        guard generation == reloadGeneration,
              selectedCalendarIdentifier == calendarIdentifier else { return }

        let incompleteReminders = fetched.filter { !$0.isCompleted }
        reminders = incompleteReminders
        lastSyncedAt = now()
        syncState = .synced
    }

    func selectCalendar(_ identifier: String) {
        guard calendars.contains(where: { $0.calendarIdentifier == identifier }) else { return }
        setSelectedCalendarIdentifier(identifier)
        Task { await reload() }
    }

    func dueMode(for reminder: EKReminder) -> ReminderDueMode {
        return ReminderDueMode(components: reminder.dueDateComponents)
    }

    @discardableResult
    func addReminder(title: String) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              let calendar = selectedCalendar,
              selectedCalendarIsWritable else { return false }

        let reminder = eventStore.makeReminder()
        reminder.calendar = calendar
        reminder.title = cleanTitle

        do {
            try eventStore.save(reminder, commit: true)
            let identifier = reminder.calendarItemIdentifier
            await reload()
            lastAddedReminderIdentifier = identifier
            return true
        } catch {
            syncState = .failed(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func setCompleted(_ reminder: EKReminder, completed: Bool = true) async -> Bool {
        guard canModify(reminder) else { return false }
        let previousValue = reminder.isCompleted
        let previousReminders = reminders
        reminder.isCompleted = completed
        reminders.removeAll {
            $0.calendarItemIdentifier == reminder.calendarItemIdentifier
        }

        do {
            try eventStore.save(reminder, commit: true)
            await reload()
            return true
        } catch {
            reminder.isCompleted = previousValue
            reminders = previousReminders
            syncState = .failed(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func createCalendar(title: String) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard authorization == .fullAccess, !cleanTitle.isEmpty else { return false }

        do {
            let calendar = try eventStore.createReminderCalendar(title: cleanTitle)
            loadCalendars()
            setSelectedCalendarIdentifier(calendar.calendarIdentifier)
            await reload()
            return true
        } catch {
            syncState = .failed(error.localizedDescription)
            return false
        }
    }

    func rename(_ reminder: EKReminder, to title: String) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, canModify(reminder) else { return }

        let previousTitle = reminder.title
        reminder.title = cleanTitle

        do {
            try eventStore.save(reminder, commit: true)
            await reload()
        } catch {
            reminder.title = previousTitle
            syncState = .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func update(
        _ reminder: EKReminder,
        with draft: ReminderDraft,
        fields requestedFields: Set<ReminderEditField>
    ) async -> ReminderUpdateResult {
        guard canModify(reminder) else { return .failed }
        var fields = requestedFields
        var rejectedFields: Set<ReminderEditField> = []
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if fields.contains(.title), cleanTitle.isEmpty {
            fields.remove(.title)
            rejectedFields.insert(.title)
        }
        guard !fields.isEmpty else {
            return .saved(rejecting: rejectedFields)
        }

        let previousTitle = reminder.title
        let previousNotes = reminder.notes
        let previousDueDate = reminder.dueDateComponents
        let previousPriority = reminder.priority
        let previousRecurrenceRules = reminder.recurrenceRules

        if fields.contains(.title) {
            reminder.title = cleanTitle
        }
        if fields.contains(.notes) {
            reminder.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : draft.notes
        }
        if fields.contains(.dueDate) {
            reminder.dueDateComponents = draft.hasDueDate || draft.hasDueTime
                ? Self.dueDateComponents(for: draft)
                : nil
        }
        if fields.contains(.priority) {
            reminder.priority = draft.priority.rawValue
        }
        if fields.contains(.recurrence), draft.recurrence != .custom {
            reminder.recurrenceRules = draft.recurrence.recurrenceRule.map { [$0] }
        }

        syncState = .syncing
        do {
            try eventStore.save(reminder, commit: true)
            lastSyncedAt = now()
            syncState = .synced
            return .saved(rejecting: rejectedFields)
        } catch {
            reminder.title = previousTitle
            reminder.notes = previousNotes
            reminder.dueDateComponents = previousDueDate
            reminder.priority = previousPriority
            reminder.recurrenceRules = previousRecurrenceRules
            syncState = .failed(error.localizedDescription)
            return .failed
        }
    }

    var syncErrorMessage: String? {
        guard case let .failed(message) = syncState else { return nil }
        return message
    }

    func clearSyncError() {
        guard case .failed = syncState else { return }
        syncState = .idle
    }

    func delete(_ reminder: EKReminder) async {
        guard canModify(reminder) else { return }
        do {
            try eventStore.remove(reminder, commit: true)
            await reload()
        } catch {
            syncState = .failed(error.localizedDescription)
        }
    }

    private func resolveAuthorization(requestIfNeeded: Bool) async {
        let status = eventStore.authorizationStatus()

        switch status {
        case .fullAccess, .authorized:
            authorization = .fullAccess
            loadCalendars()
            await reload()
        case .notDetermined where requestIfNeeded:
            authorization = .requesting
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                authorization = granted ? .fullAccess : .denied
                if granted {
                    loadCalendars()
                    await reload()
                }
            } catch {
                authorization = .denied
                syncState = .failed(error.localizedDescription)
            }
        case .notDetermined:
            authorization = .notDetermined
            clearEventKitContent()
        case .restricted:
            authorization = .restricted
            clearEventKitContent()
        case .denied, .writeOnly:
            authorization = .denied
            clearEventKitContent()
        @unknown default:
            authorization = .denied
            clearEventKitContent()
        }
    }

    private func clearEventKitContent() {
        reloadGeneration &+= 1
        calendars = []
        reminders = []
        selectedCalendarIdentifier = nil
        lastSyncedAt = nil
        lastAddedReminderIdentifier = nil
        syncState = .idle
    }

    private func loadCalendars() {
        calendars = eventStore.calendars(for: .reminder).sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }

        if let selectedCalendarIdentifier,
           calendars.contains(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            return
        }

        if let rememberedIdentifier = userDefaults?.string(
            forKey: Self.selectedCalendarIdentifierDefaultsKey
        ), calendars.contains(where: { $0.calendarIdentifier == rememberedIdentifier }) {
            selectedCalendarIdentifier = rememberedIdentifier
            return
        }

        let defaultIdentifier = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        let fallbackIdentifier = defaultIdentifier ?? calendars.first?.calendarIdentifier
        if let fallbackIdentifier {
            setSelectedCalendarIdentifier(fallbackIdentifier)
        } else {
            selectedCalendarIdentifier = nil
        }
    }

    private func setSelectedCalendarIdentifier(_ identifier: String) {
        selectedCalendarIdentifier = identifier
        userDefaults?.set(identifier, forKey: Self.selectedCalendarIdentifierDefaultsKey)
    }

    @objc
    private func eventStoreDidChange() {
        Task {
            guard authorization == .fullAccess else { return }
            loadCalendars()
            await reload()
        }
    }

    private static func dueDateComponents(for draft: ReminderDraft) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent

        var requestedComponents: Set<Calendar.Component> = []
        if draft.dueMode != .none {
            requestedComponents.formUnion([.year, .month, .day])
        }
        if draft.hasDueTime {
            requestedComponents.formUnion([.hour, .minute])
        }

        var components = calendar.dateComponents(requestedComponents, from: draft.dueDate)
        components.calendar = calendar
        components.timeZone = draft.hasDueTime ? .autoupdatingCurrent : nil
        return components
    }

}
