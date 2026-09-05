import AppKit
import EventKit
import SwiftUI

struct ReminderListView: View {
    let store: RemindersStore
    let isPanelExpanded: Bool
    let collapseRequest: Int
    let searchQuery: String
    let onTransientInteraction: (Bool) -> Void

    @State private var expandedReminderIdentifier: String?
    @State private var menuTracking = NotchMenuTrackingState()
    @State private var scrollIndicatorTrigger = 0
    @State private var revealTask: Task<Void, Never>?
    @State private var deletionConfirmation = ReminderDeletionConfirmation()
    @State private var reminderContentRevision = 0

    var body: some View {
        listContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: isPanelExpanded) { _, panelIsExpanded in
                if !panelIsExpanded {
                    collapseExpandedReminder()
                }
            }
            .onChange(of: store.reminders.map(\.calendarItemIdentifier)) {
                _, identifiers in
                deletionConfirmation.cancelIfReminderIsMissing(from: identifiers)
            }
            .onChange(of: visibleReminderIdentifiers) { _, identifiers in
                guard let expandedReminderIdentifier,
                      !identifiers.contains(expandedReminderIdentifier) else { return }
                self.expandedReminderIdentifier = nil
            }
            .onChange(of: collapseRequest) { _, _ in
                collapseExpandedReminder()
            }
            .onChange(of: deletionConfirmation.pendingReminder != nil) {
                _, _ in
                reportTransientInteraction()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            ) { _ in
                // App-wide menu notifications also arrive from Settings and capture.
                if menuTracking.beginTracking(
                    isOwnerActive: isPanelExpanded && NSApp.keyWindow is NotchPanel
                ) {
                    reportTransientInteraction()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            ) { _ in
                if menuTracking.endTracking() {
                    reportTransientInteraction()
                }
            }
            .deleteConfirmationAlert(
                isPresented: isDeleteConfirmationPresented,
                reminder: deletionConfirmation.pendingReminder,
                onDelete: confirmReminderDeletion,
                onCancel: deletionConfirmation.cancelDeletion
            )
            .onDisappear {
                revealTask?.cancel()
                revealTask = nil
                deletionConfirmation.cancelDeletion()
                _ = menuTracking.reset()
                reportTransientInteraction()
            }
    }

    @ViewBuilder
    private var listContent: some View {
        Group {
            if store.reminders.isEmpty {
                emptyState
            } else if visibleReminders.isEmpty {
                noSearchResultsState
            } else {
                ScrollViewReader { scrollProxy in
                    List(visibleReminders, id: \.calendarItemIdentifier) { reminder in
                        reminderCell(
                            reminder,
                            isLast: reminder.calendarItemIdentifier
                                == visibleReminders.last?.calendarItemIdentifier
                        )
                        .id(reminder.calendarItemIdentifier)
                    }
                    .listStyle(.plain)
                    .contentMargins(.horizontal, 0, for: .scrollContent)
                    .scrollContentBackground(.hidden)
                    .transientVerticalScrollIndicator(trigger: scrollIndicatorTrigger)
                    .padding(.leading, -8)
                    .padding(.trailing, -10)
                    .background {
                        ScrollActivityDetector(
                            expandedRowIndex: expandedRowIndex,
                            onScroll: {
                                scrollIndicatorTrigger &+= 1
                            },
                            onOutsideClick: collapseExpandedReminder,
                            onEscape: collapseExpandedReminder
                        )
                    }
                    .onChange(of: expandedReminderIdentifier) { _, identifier in
                        scheduleRevealIfNeeded(identifier, using: scrollProxy)
                    }
                    .task(id: store.lastAddedReminderIdentifier) {
                        let identifier = store.lastAddedReminderIdentifier
                        guard let identifier else { return }
                        guard visibleReminders.contains(where: {
                            $0.calendarItemIdentifier == identifier
                        }) else { return }

                        try? await Task.sleep(for: .milliseconds(150))
                        guard !Task.isCancelled else { return }

                        scrollProxy.scrollTo(identifier, anchor: .bottom)

                        // List can report the inserted identity one layout pass
                        // before its final row height is committed.
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled else { return }
                        scrollProxy.scrollTo(identifier, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func reminderCell(_ reminder: EKReminder, isLast: Bool) -> some View {
        let isEditable = store.canModify(reminder)
        return ReminderRow(
            reminder: reminder,
            calendarColor: store.color(for: reminder),
            dueMode: store.dueMode(for: reminder),
            isEditable: isEditable,
            isExpanded: expansionBinding(for: reminder.calendarItemIdentifier),
            onTransientInteraction: onTransientInteraction,
            isReminderPresent: {
                store.reminders.contains {
                    $0.calendarItemIdentifier == reminder.calendarItemIdentifier
                }
            },
            onUpdate: { draft, fields in
                let result = await store.update(reminder, with: draft, fields: fields)
                reminderContentRevision &+= 1
                return result
            },
            onComplete: {
                await store.setCompleted(reminder)
            }
        )
            .padding(.bottom, isLast ? 14 : 0)
            .listRowInsets(
                EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteReminder(reminder)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!isEditable)
            }
    }

    private func expansionBinding(for identifier: String) -> Binding<Bool> {
        Binding(
            get: { expandedReminderIdentifier == identifier },
            set: { shouldExpand in
                expandedReminderIdentifier = shouldExpand ? identifier : nil
            }
        )
    }

    private func collapseExpandedReminder() {
        guard expandedReminderIdentifier != nil else { return }
        expandedReminderIdentifier = nil
    }

    private var expandedRowIndex: Int? {
        guard let expandedReminderIdentifier else { return nil }
        return visibleReminders.firstIndex {
            $0.calendarItemIdentifier == expandedReminderIdentifier
        }
    }

    private func scheduleRevealIfNeeded(
        _ identifier: String?,
        using scrollProxy: ScrollViewProxy
    ) {
        revealTask?.cancel()
        revealTask = nil
        guard let identifier else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled,
                  expandedReminderIdentifier == identifier else { return }

            scrollProxy.scrollTo(
                identifier,
                anchor: identifier == visibleReminders.last?.calendarItemIdentifier
                    ? .bottom
                    : .center
            )
        }
    }

    private func deleteReminder(_ reminder: EKReminder) {
        guard deletionConfirmation.requestDeletion(of: reminder) else { return }
        performDeletion(of: reminder)
    }

    private func confirmReminderDeletion(_ reminder: EKReminder) {
        _ = deletionConfirmation.confirmDeletion()
        performDeletion(of: reminder)
    }

    private func performDeletion(of reminder: EKReminder) {
        Task { await store.delete(reminder) }
    }

    private func reportTransientInteraction() {
        onTransientInteraction(
            menuTracking.isTracking || deletionConfirmation.pendingReminder != nil
        )
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { deletionConfirmation.pendingReminder != nil },
            set: { isPresented in
                if !isPresented {
                    deletionConfirmation.cancelDeletion()
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(store.selectedCalendarColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: isReadOnlyEmptyList ? "lock.fill" : "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(store.selectedCalendarColor)
            }
            Text(isReadOnlyEmptyList ? "No open reminders" : "Nothing left here")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
            Text(
                isReadOnlyEmptyList
                    ? "This read-only list is currently empty."
                    : "A very good kind of empty."
            )
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isReadOnlyEmptyList: Bool {
        store.selectedSmartScope == nil && !store.selectedCalendarIsWritable
    }

    private var visibleReminders: [EKReminder] {
        _ = reminderContentRevision
        return ReminderSearchMatcher.filter(store.reminders, query: searchQuery)
    }

    private var visibleReminderIdentifiers: [String] {
        visibleReminders.map(\.calendarItemIdentifier)
    }

    private var noSearchResultsState: some View {
        VStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
            Text("No matching reminders")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
            Text("Try a different search.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
