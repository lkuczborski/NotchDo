import Combine
import EventKit
import Foundation

@MainActor
final class RemindersStore: NSObject, ObservableObject {
    @Published private(set) var authorization: ReminderAuthorizationState = .notDetermined
    @Published private(set) var syncState: ReminderSyncState = .idle
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var reminders: [EKReminder] = []
    @Published private(set) var selectedCalendarIdentifier: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastAddedReminderIdentifier: String?

    private let eventStore: any ReminderEventStore
    private let now: () -> Date
    private var preferredOrderByCalendar: [String: [String]] = [:]

    override init() {
        eventStore = EKEventStore()
        now = Date.init
        super.init()
        observeEventStoreChanges()
    }

    init(
        eventStore: any ReminderEventStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.eventStore = eventStore
        self.now = now
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

    func start() async {
        await resolveAuthorization(requestIfNeeded: false)
    }

    func requestAccess() async {
        await resolveAuthorization(requestIfNeeded: true)
    }

    func reload() async {
        guard authorization == .fullAccess else { return }
        guard let calendar = selectedCalendar else {
            reminders = []
            return
        }

        syncState = .syncing
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let fetched: [EKReminder] = await withCheckedContinuation { continuation in
            _ = eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        let incompleteReminders = fetched.filter { !$0.isCompleted }
        reminders = orderedReminders(
            incompleteReminders,
            calendarIdentifier: calendar.calendarIdentifier
        )
        preferredOrderByCalendar[calendar.calendarIdentifier]
            = reminders.map(\.calendarItemIdentifier)
        lastSyncedAt = now()
        syncState = .synced
    }

    func selectCalendar(_ identifier: String) {
        guard calendars.contains(where: { $0.calendarIdentifier == identifier }) else { return }
        selectedCalendarIdentifier = identifier
        Task { await reload() }
    }

    @discardableResult
    func addReminder(title: String) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let calendar = selectedCalendar else { return false }

        let reminder = eventStore.makeReminder()
        reminder.calendar = calendar
        reminder.title = cleanTitle

        do {
            try eventStore.save(reminder, commit: true)
            let identifier = reminder.calendarItemIdentifier
            appendToPreferredOrder(
                identifier,
                calendarIdentifier: calendar.calendarIdentifier
            )
            await reload()
            lastAddedReminderIdentifier = identifier
            return true
        } catch {
            syncState = .failed(error.localizedDescription)
            return false
        }
    }

    func setCompleted(_ reminder: EKReminder, completed: Bool = true) async {
        let previousValue = reminder.isCompleted
        let previousReminders = reminders
        reminder.isCompleted = completed
        reminders.removeAll {
            $0.calendarItemIdentifier == reminder.calendarItemIdentifier
        }

        do {
            try eventStore.save(reminder, commit: true)
            await reload()
        } catch {
            reminder.isCompleted = previousValue
            reminders = previousReminders
            syncState = .failed(error.localizedDescription)
        }
    }

    func moveReminder(
        _ movingIdentifier: String,
        relativeTo targetIdentifier: String,
        placeAfter: Bool
    ) {
        guard movingIdentifier != targetIdentifier,
              let movingIndex = reminders.firstIndex(where: {
                  $0.calendarItemIdentifier == movingIdentifier
              }),
              reminders.contains(where: {
                  $0.calendarItemIdentifier == targetIdentifier
              }) else { return }

        var reordered = reminders
        let movingReminder = reordered.remove(at: movingIndex)
        guard let targetIndex = reordered.firstIndex(where: {
            $0.calendarItemIdentifier == targetIdentifier
        }) else { return }

        let insertionIndex = targetIndex + (placeAfter ? 1 : 0)
        reordered.insert(movingReminder, at: insertionIndex)
        reminders = reordered

        if let selectedCalendarIdentifier {
            preferredOrderByCalendar[selectedCalendarIdentifier]
                = reordered.map(\.calendarItemIdentifier)
        }
    }

    func rename(_ reminder: EKReminder, to title: String) async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

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

    func update(
        _ reminder: EKReminder,
        with draft: ReminderDraft,
        fields requestedFields: Set<ReminderEditField>
    ) async {
        var fields = requestedFields
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            fields.remove(.title)
        }
        guard !fields.isEmpty else { return }

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
            reminder.dueDateComponents = draft.hasDueDate
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
        } catch {
            reminder.title = previousTitle
            reminder.notes = previousNotes
            reminder.dueDateComponents = previousDueDate
            reminder.priority = previousPriority
            reminder.recurrenceRules = previousRecurrenceRules
            syncState = .failed(error.localizedDescription)
        }
    }

    func delete(_ reminder: EKReminder) async {
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
        case .restricted:
            authorization = .restricted
        case .denied, .writeOnly:
            authorization = .denied
        @unknown default:
            authorization = .denied
        }
    }

    private func loadCalendars() {
        calendars = eventStore.calendars(for: .reminder).sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }

        if let selectedCalendarIdentifier,
           calendars.contains(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            return
        }

        let defaultIdentifier = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        selectedCalendarIdentifier = defaultIdentifier ?? calendars.first?.calendarIdentifier
    }

    @objc
    private func eventStoreDidChange() {
        Task {
            guard authorization == .fullAccess else { return }
            loadCalendars()
            await reload()
        }
    }

    private static func reminderSort(_ lhs: EKReminder, _ rhs: EKReminder) -> Bool {
        switch (lhs.notchDueDate, rhs.notchDueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return (lhs.title ?? "").localizedStandardCompare(rhs.title ?? "") == .orderedAscending
        }
    }

    private func orderedReminders(
        _ fetched: [EKReminder],
        calendarIdentifier: String
    ) -> [EKReminder] {
        let reminderByIdentifier = Dictionary(
            uniqueKeysWithValues: fetched.map { ($0.calendarItemIdentifier, $0) }
        )
        let preferredOrder = preferredOrderByCalendar[calendarIdentifier] ?? []

        guard !preferredOrder.isEmpty else {
            return fetched.sorted(by: Self.reminderSort)
        }

        var includedIdentifiers = Set<String>()
        var ordered = preferredOrder.compactMap { identifier -> EKReminder? in
            guard let reminder = reminderByIdentifier[identifier] else { return nil }
            includedIdentifiers.insert(identifier)
            return reminder
        }

        let unseenReminders = fetched
            .filter { !includedIdentifiers.contains($0.calendarItemIdentifier) }
            .sorted(by: Self.reminderSort)
        ordered.append(contentsOf: unseenReminders)
        return ordered
    }

    private func appendToPreferredOrder(
        _ identifier: String,
        calendarIdentifier: String
    ) {
        var order = preferredOrderByCalendar[calendarIdentifier]
            ?? reminders.map(\.calendarItemIdentifier)
        order.removeAll { $0 == identifier }
        order.append(identifier)
        preferredOrderByCalendar[calendarIdentifier] = order
    }

    private static func dueDateComponents(for draft: ReminderDraft) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent

        var components = calendar.dateComponents(
            draft.isAllDay
                ? [.year, .month, .day]
                : [.year, .month, .day, .hour, .minute],
            from: draft.dueDate
        )
        components.calendar = calendar
        components.timeZone = draft.isAllDay ? nil : .autoupdatingCurrent
        return components
    }
}
