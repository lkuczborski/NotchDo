import EventKit
import SwiftUI

struct ReminderListView: View {
    let store: RemindersStore
    let isPanelExpanded: Bool
    let collapseRequest: Int
    let onTransientInteraction: (Bool) -> Void

    @State private var expandedReminderIdentifier: String?
    @State private var scrollIndicatorTrigger = 0
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        Group {
            if store.reminders.isEmpty {
                emptyState
            } else {
                ScrollViewReader { scrollProxy in
                    List(store.reminders, id: \.calendarItemIdentifier) { reminder in
                        reminderCell(
                            reminder,
                            isLast: reminder.calendarItemIdentifier
                                == store.reminders.last?.calendarItemIdentifier
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
                        guard store.reminders.contains(where: {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isPanelExpanded) { _, panelIsExpanded in
            if !panelIsExpanded {
                collapseExpandedReminder()
            }
        }
        .onChange(of: store.reminders.map(\.calendarItemIdentifier)) { _, identifiers in
            guard let expandedReminderIdentifier,
                  !identifiers.contains(expandedReminderIdentifier) else { return }
            self.expandedReminderIdentifier = nil
        }
        .onChange(of: collapseRequest) { _, _ in
            collapseExpandedReminder()
        }
        .onExitCommand {
            collapseExpandedReminder()
        }
        .onDisappear {
            revealTask?.cancel()
            revealTask = nil
        }
    }

    private func reminderCell(_ reminder: EKReminder, isLast: Bool) -> some View {
        ReminderRow(
            reminder: reminder,
            calendarColor: store.selectedCalendarColor,
            dueMode: store.dueMode(for: reminder),
            isExpanded: expansionBinding(for: reminder.calendarItemIdentifier),
            onTransientInteraction: onTransientInteraction,
            isReminderPresent: {
                store.reminders.contains {
                    $0.calendarItemIdentifier == reminder.calendarItemIdentifier
                }
            },
            onUpdate: { draft, fields in
                await store.update(reminder, with: draft, fields: fields)
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
        return store.reminders.firstIndex {
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
                anchor: identifier == store.reminders.last?.calendarItemIdentifier
                    ? .bottom
                    : .center
            )
        }
    }

    private func deleteReminder(_ reminder: EKReminder) {
        Task { await store.delete(reminder) }
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(store.selectedCalendarColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(store.selectedCalendarColor)
            }
            Text("Nothing left here")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
            Text("A very good kind of empty.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
