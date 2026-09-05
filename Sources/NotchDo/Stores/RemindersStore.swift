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
    private(set) var selectedSmartScope: ReminderSmartScope?
    private(set) var lastSyncedAt: Date?
    private(set) var lastAddedReminderIdentifier: String?
    private(set) var recentlyCompletedReminder: EKReminder?

    private let eventStore: any ReminderEventStore
    private let now: () -> Date
    private let calendar: Calendar
    private let userDefaults: UserDefaults?
    private let completionUndoDuration: Duration
    private let completionUndoSleep: @MainActor (Duration) async -> Void
    private var reloadGeneration = 0
    private var completionUndoGeneration = 0
    private var completionUndoExpiryTask: Task<Void, Never>?

    override init() {
        eventStore = EKEventStore()
        now = Date.init
        calendar = .autoupdatingCurrent
        userDefaults = .standard
        completionUndoDuration = .seconds(5)
        completionUndoSleep = { duration in
            try? await Task.sleep(for: duration)
        }
        super.init()
        observeEventStoreChanges()
    }

    init(
        eventStore: any ReminderEventStore,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        userDefaults: UserDefaults? = nil,
        completionUndoDuration: Duration = .seconds(5),
        completionUndoSleep: @escaping @MainActor (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        }
    ) {
        self.eventStore = eventStore
        self.now = now
        self.calendar = calendar
        self.userDefaults = userDefaults
        self.completionUndoDuration = completionUndoDuration
        self.completionUndoSleep = completionUndoSleep
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
        selectedSmartScope?.title ?? selectedCalendar?.title ?? "Reminders"
    }

    var selectedCalendarIsWritable: Bool {
        guard selectedSmartScope == nil,
              authorization == .fullAccess,
              let selectedCalendar else { return false }
        return eventStore.allowsContentModifications(in: selectedCalendar)
    }

    var writableCalendars: [EKCalendar] {
        guard authorization == .fullAccess else { return [] }
        return calendars.filter { eventStore.allowsContentModifications(in: $0) }
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
        guard selectedSmartScope != nil || selectedCalendar != nil else {
            reminders = []
            syncState = .idle
            return
        }
        guard selectedSmartScope == nil || !calendars.isEmpty else {
            reminders = []
            syncState = .idle
            return
        }

        let requestedScope = selectedSmartScope
        let requestedCalendarIdentifier = selectedCalendarIdentifier
        let requestedCalendars = requestedScope == nil
            ? selectedCalendar.map { [$0] } ?? []
            : calendars
        syncState = .syncing
        let predicate = eventStore.predicateForReminders(in: requestedCalendars)
        let fetched: [EKReminder] = await withCheckedContinuation { continuation in
            _ = eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        guard generation == reloadGeneration,
              selectedSmartScope == requestedScope,
              selectedCalendarIdentifier == requestedCalendarIdentifier else { return }

        let membership = ReminderSmartScopeMembership(now: now(), calendar: calendar)
        let incompleteReminders = fetched.filter { reminder in
            if let requestedScope {
                return membership.contains(
                    isCompleted: reminder.isCompleted,
                    dueDateComponents: reminder.dueDateComponents,
                    in: requestedScope
                )
            }
            return !reminder.isCompleted
        }
        reminders = incompleteReminders
        lastSyncedAt = now()
        syncState = .synced
    }

    func selectCalendar(_ identifier: String) {
        guard calendars.contains(where: { $0.calendarIdentifier == identifier }) else { return }
        selectedSmartScope = nil
        setSelectedCalendarIdentifier(identifier)
        Task { await reload() }
    }

    func selectSmartScope(_ scope: ReminderSmartScope) {
        guard selectedSmartScope != scope else { return }
        dismissCompletionUndo()
        selectedSmartScope = scope
        Task { await reload() }
    }

    func dueMode(for reminder: EKReminder) -> ReminderDueMode {
        return ReminderDueMode(components: reminder.dueDateComponents)
    }

    @discardableResult
    func addReminder(title: String) async -> Bool {
        await addReminder(
            draft: ReminderDraft(title: title),
            calendarIdentifier: selectedCalendarIdentifier
        )
    }

    @discardableResult
    func addReminder(
        draft: ReminderDraft,
        calendarIdentifier: String?
    ) async -> Bool {
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              authorization == .fullAccess,
              let calendar = calendars.first(where: {
                  $0.calendarIdentifier == calendarIdentifier
              }),
              eventStore.allowsContentModifications(in: calendar) else { return false }

        let reminder = eventStore.makeReminder()
        reminder.calendar = calendar
        reminder.title = cleanTitle
        let cleanNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = cleanNotes.isEmpty ? nil : draft.notes
        reminder.dueDateComponents = draft.dueMode == .none
            ? nil
            : Self.dueDateComponents(for: draft)
        reminder.priority = draft.priority.rawValue
        if draft.recurrence != .custom {
            reminder.recurrenceRules = draft.recurrence.recurrenceRule.map { [$0] }
        }

        syncState = .syncing
        do {
            try eventStore.save(reminder, commit: true)
            let identifier = reminder.calendarItemIdentifier
            await reload()
            lastAddedReminderIdentifier = identifier
            return true
        } catch {
            syncState = .failed("Couldn’t add the reminder. \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func setCompleted(_ reminder: EKReminder, completed: Bool = true) async -> Bool {
        guard canModify(reminder) else { return false }
        let previousValue = reminder.isCompleted
        let previousReminders = reminders
        let selectedScope = selectedSmartScope
        let completionCalendarIdentifier = selectedCalendarIdentifier
        reminder.isCompleted = completed
        reminders.removeAll {
            $0.calendarItemIdentifier == reminder.calendarItemIdentifier
        }

        do {
            try eventStore.save(reminder, commit: true)
            let completionGeneration: Int?
            if completed {
                dismissCompletionUndo()
                completionGeneration = completionUndoGeneration
            } else {
                completionGeneration = nil
            }
            await reload()
            if let completionGeneration,
               completionUndoGeneration == completionGeneration,
               self.selectedSmartScope == selectedScope,
               self.selectedCalendarIdentifier == completionCalendarIdentifier {
                presentCompletionUndo(for: reminder)
            }
            return true
        } catch {
            reminder.isCompleted = previousValue
            reminders = previousReminders
            syncState = .failed("Couldn’t change the reminder’s completion. \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func undoRecentCompletion() async -> Bool {
        guard let reminder = recentlyCompletedReminder else { return false }
        dismissCompletionUndo()
        return await setCompleted(reminder, completed: false)
    }

    func dismissCompletionUndo() {
        completionUndoGeneration &+= 1
        completionUndoExpiryTask?.cancel()
        completionUndoExpiryTask = nil
        recentlyCompletedReminder = nil
    }

    @discardableResult
    func createCalendar(title: String) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard authorization == .fullAccess, !cleanTitle.isEmpty else { return false }

        do {
            let calendar = try eventStore.createReminderCalendar(title: cleanTitle)
            loadCalendars()
            selectedSmartScope = nil
            setSelectedCalendarIdentifier(calendar.calendarIdentifier)
            await reload()
            return true
        } catch {
            syncState = .failed("Couldn’t create the list. \(error.localizedDescription)")
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
            syncState = .failed("Couldn’t rename the reminder. \(error.localizedDescription)")
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
            if selectedSmartScope != nil {
                await reload()
            } else {
                lastSyncedAt = now()
                syncState = .synced
            }
            return .saved(rejecting: rejectedFields)
        } catch {
            reminder.title = previousTitle
            reminder.notes = previousNotes
            reminder.dueDateComponents = previousDueDate
            reminder.priority = previousPriority
            reminder.recurrenceRules = previousRecurrenceRules
            syncState = .failed("Couldn’t save the reminder. \(error.localizedDescription)")
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
            syncState = .failed("Couldn’t delete the reminder. \(error.localizedDescription)")
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
                syncState = .failed("Couldn’t access Reminders. \(error.localizedDescription)")
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
        selectedSmartScope = nil
        if !setSelectedCalendarIdentifier(nil) {
            dismissCompletionUndo()
        }
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
            setSelectedCalendarIdentifier(rememberedIdentifier)
            return
        }

        let defaultIdentifier = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        let fallbackIdentifier = defaultIdentifier ?? calendars.first?.calendarIdentifier
        if let fallbackIdentifier {
            setSelectedCalendarIdentifier(fallbackIdentifier)
        } else {
            setSelectedCalendarIdentifier(nil)
        }
    }

    @discardableResult
    private func setSelectedCalendarIdentifier(_ identifier: String?) -> Bool {
        guard selectedCalendarIdentifier != identifier else { return false }
        dismissCompletionUndo()
        selectedCalendarIdentifier = identifier
        if let identifier {
            userDefaults?.set(identifier, forKey: Self.selectedCalendarIdentifierDefaultsKey)
        }
        return true
    }

    private func presentCompletionUndo(for reminder: EKReminder) {
        completionUndoExpiryTask?.cancel()
        recentlyCompletedReminder = reminder
        let identifier = reminder.calendarItemIdentifier
        completionUndoExpiryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await completionUndoSleep(completionUndoDuration)
            guard !Task.isCancelled,
                  recentlyCompletedReminder?.calendarItemIdentifier == identifier else { return }
            dismissCompletionUndo()
        }
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
