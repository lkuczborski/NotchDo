import SwiftUI

struct ReminderListView: View {
    @ObservedObject var store: RemindersStore
    let isPanelExpanded: Bool
    let collapseRequest: Int
    @Binding var isPointerInsideReminderRow: Bool

    @State private var expandedReminderIdentifier: String?

    var body: some View {
        Group {
            if store.reminders.isEmpty {
                emptyState
            } else {
                ScrollViewReader { scrollProxy in
                    List {
                        ForEach(store.reminders, id: \.calendarItemIdentifier) { reminder in
                            ReminderRow(
                                reminder: reminder,
                                store: store,
                                isExpanded: expansionBinding(
                                    for: reminder.calendarItemIdentifier
                                ),
                                onHoverChange: { hovering in
                                    isPointerInsideReminderRow = hovering
                                }
                            )
                            .id(reminder.calendarItemIdentifier)
                            .draggable(reminder.calendarItemIdentifier)
                            .dropDestination(for: String.self) { identifiers, location in
                                guard let movingIdentifier = identifiers.first else {
                                    return false
                                }

                                collapseExpandedReminder()
                                store.moveReminder(
                                    movingIdentifier,
                                    relativeTo: reminder.calendarItemIdentifier,
                                    placeAfter: location.y > 24
                                )
                                return true
                            }
                            .listRowInsets(
                                EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0)
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .background {
                                if reminder.calendarItemIdentifier
                                    == store.reminders.first?.calendarItemIdentifier {
                                    ScrollActivityDetector {
                                        collapseExpandedReminder()
                                    } onBackgroundClick: {
                                        collapseExpandedReminder()
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await store.delete(reminder) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .contentMargins(.horizontal, 0, for: .scrollContent)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -8)
                    .onChange(of: store.lastAddedReminderIdentifier) { _, identifier in
                        guard let identifier else { return }
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
                                scrollProxy.scrollTo(identifier, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            .smooth(duration: 0.24, extraBounce: 0),
            value: store.reminders.map(\.calendarItemIdentifier)
        )
        .onChange(of: isPanelExpanded) { _, panelIsExpanded in
            if !panelIsExpanded {
                isPointerInsideReminderRow = false
                collapseExpandedReminder()
            }
        }
        .onChange(of: collapseRequest) { _, _ in
            collapseExpandedReminder()
        }
        .onKeyPress(.escape) {
            guard expandedReminderIdentifier != nil else { return .ignored }
            collapseExpandedReminder()
            return .handled
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
                .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
