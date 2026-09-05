import SwiftUI

struct NotchRootView: View {
    let store: RemindersStore
    @ObservedObject var layout: NotchLayoutModel
    @ObservedObject var interaction: NotchInteractionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rowCollapseRequest = 0
    @State private var expandedCountFrame: CGRect = .zero
    @State private var search = ReminderSearchState()
    @State private var isCreateListPresented = false
    @State private var newListTitle = ""
    @State private var isHeaderPresented = false
    @State private var isErrorPresented = false
    @State private var isRowPresented = false

    var body: some View {
        ZStack(alignment: .top) {
            expandingSurface
            taskCountBadge
        }
        .frame(
            width: layout.metrics.expandedSize.width,
            height: layout.metrics.expandedSize.height,
            alignment: .top
        )
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .coordinateSpace(name: NotchCoordinateSpace.root)
        .onPreferenceChange(TaskCountBadgeFrameKey.self) { frame in
            expandedCountFrame = frame
        }
        .onTapGesture {
            interaction.expand()
        }
        .background {
            SyncErrorPresenter(
                store: store,
                onPresentationChange: { isPresented in
                    isErrorPresented = isPresented
                    reportTransientInteraction()
                }
            )
        }
        .alert("New List", isPresented: $isCreateListPresented) {
            TextField("List name", text: $newListTitle)
            Button("Cancel", role: .cancel) {
                newListTitle = ""
            }
            Button("Create") {
                let title = newListTitle
                newListTitle = ""
                Task { await store.createCalendar(title: title) }
            }
            .disabled(newListTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("This list will appear in Apple Reminders.")
        }
        .onChange(of: isCreateListPresented) { _, _ in
            reportTransientInteraction()
        }
        .animation(surfaceAnimation, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                search.dismiss()
            }
        }
        .onExitCommand(perform: handleEscape)
    }

    private var expandingSurface: some View {
        ZStack(alignment: .top) {
            Color.black

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: layout.metrics.bridgeHeight + 2)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: collapseReminderRows)
                    .accessibilityLabel("NotchDo")

                expandedContent
            }
            .frame(
                width: layout.metrics.expandedSize.width,
                height: layout.metrics.expandedSize.height
            )
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .mask(alignment: .top) {
            surfaceShape
                .frame(width: surfaceSize.width, height: surfaceSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .compositingGroup()
    }

    private var isExpanded: Bool {
        interaction.isExpanded
    }

    private var surfaceSize: CGSize {
        isExpanded ? layout.metrics.expandedSize : layout.metrics.collapsedSize
    }

    private var expandedContent: some View {
        VStack(spacing: 12) {
            NotchHeaderView(
                store: store,
                onInteraction: collapseReminderRows,
                onSearch: presentSearch,
                onTransientInteractionChange: { isPresented in
                    isHeaderPresented = isPresented
                    reportTransientInteraction()
                },
                onCreateList: { isCreateListPresented = true }
            )

            if search.isPresented {
                ReminderSearchView(
                    query: $search.query,
                    focusRequest: search.focusRequest,
                    resultCount: filteredReminderCount,
                    totalCount: store.reminders.count,
                    onDismiss: dismissSearch
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            content

            if store.authorization == .fullAccess {
                if let reminder = store.recentlyCompletedReminder {
                    CompletionUndoView(
                        reminderTitle: reminder.title,
                        color: store.color(for: reminder),
                        onUndo: undoRecentCompletion
                    )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
                }

                if store.selectedSmartScope != nil {
                    EmptyView()
                } else if store.selectedCalendarIsWritable {
                    ComposerView(
                        store: store,
                        isActive: isExpanded,
                        onInteraction: collapseReminderRows
                    )
                } else if store.selectedCalendar != nil {
                    ReadOnlyListNotice()
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.2, extraBounce: 0),
            value: store.recentlyCompletedReminder?.calendarItemIdentifier
        )
    }

    private var taskCountBadge: some View {
        TaskCountBadge(
            count: store.reminders.count,
            color: store.selectedCalendarColor,
            diameter: isExpanded ? 22 : 20
        )
        .position(taskCountBadgePosition)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.reminders.count) open reminders")
        .zIndex(4)
    }

    private var taskCountBadgePosition: CGPoint {
        if isExpanded, !expandedCountFrame.isEmpty {
            return CGPoint(x: expandedCountFrame.midX, y: expandedCountFrame.midY)
        }

        return CGPoint(
            x: layout.metrics.expandedSize.width / 2
                - layout.metrics.collapsedSize.width / 2
                - 18,
            y: layout.metrics.bridgeHeight / 2
        )
    }

    @ViewBuilder
    private var content: some View {
        switch displayState {
        case .reminders, .emptyList:
            ReminderListView(
                store: store,
                isPanelExpanded: isExpanded,
                collapseRequest: rowCollapseRequest,
                searchQuery: search.query,
                onTransientInteraction: { isPresented in
                    isRowPresented = isPresented
                    reportTransientInteraction()
                }
            )
        case .initialLoading:
            AccessStateView(
                symbol: "arrow.triangle.2.circlepath",
                title: "Loading reminders",
                message: "",
                showsProgress: true,
                actionTitle: nil,
                action: nil
            )
        case .noCalendars:
            AccessStateView(
                symbol: "list.bullet.rectangle",
                title: "No reminder lists yet",
                message: "Create your first list here or in Apple Reminders.",
                showsProgress: false,
                actionTitle: "Create List",
                action: { isCreateListPresented = true }
            )
        case .noSelectedCalendar:
            AccessStateView(
                symbol: "list.bullet",
                title: "Choose a reminder list",
                message: "Select a list above to show its open reminders.",
                showsProgress: false,
                actionTitle: nil,
                action: nil
            )
        case .requestingPermission:
            AccessStateView(
                symbol: "checklist",
                title: "Connecting to Reminders",
                message: "Your tasks stay in Apple Reminders.",
                showsProgress: true,
                actionTitle: nil,
                action: nil
            )
        case .permissionDenied:
            AccessStateView(
                symbol: "lock.fill",
                title: "Reminders access is off",
                message: "Allow NotchDo in Privacy & Security to show and update your tasks.",
                showsProgress: false,
                actionTitle: "Open Settings",
                action: AppActions.openRemindersPrivacySettings
            )
        case .permissionRestricted:
            AccessStateView(
                symbol: "lock.shield.fill",
                title: "Reminders access is restricted",
                message: "This Mac’s privacy settings don’t currently allow NotchDo to use Reminders.",
                showsProgress: false,
                actionTitle: "Open Settings",
                action: AppActions.openRemindersPrivacySettings
            )
        case .needsPermission:
            AccessStateView(
                symbol: "checklist",
                title: "Use Apple Reminders",
                message: "View and manage your Apple Reminders lists here.",
                showsProgress: false,
                actionTitle: "Continue",
                action: { Task { await store.requestAccess() } }
            )
        }
    }

    private var displayState: ReminderDisplayState {
        ReminderDisplayState(
            authorization: store.authorization,
            calendarCount: store.calendars.count,
            hasSelectedCalendar: store.selectedSmartScope != nil || store.selectedCalendar != nil,
            reminderCount: store.reminders.count,
            selectedCalendarIsWritable: store.selectedSmartScope != nil || store.selectedCalendarIsWritable,
            syncState: store.syncState,
            lastSyncedAt: store.lastSyncedAt
        )
    }

    private var surfaceShape: NotchSurfaceShape {
        NotchSurfaceShape(
            topCornerRadius: isExpanded ? 12 : 5,
            bottomCornerRadius: isExpanded ? 28 : 12
        )
    }

    private var surfaceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .smooth(duration: isExpanded ? 0.28 : 0.22, extraBounce: 0)
    }

    private func collapseReminderRows() {
        rowCollapseRequest &+= 1
    }

    private var filteredReminderCount: Int {
        ReminderSearchMatcher.filter(store.reminders, query: search.query).count
    }

    private func presentSearch() {
        collapseReminderRows()
        search.present()
    }

    private func dismissSearch() {
        search.dismiss()
    }

    private func handleEscape() {
        if search.isPresented {
            dismissSearch()
        } else {
            collapseReminderRows()
        }
    }

    private func undoRecentCompletion() {
        Task { await store.undoRecentCompletion() }
    }

    private func reportTransientInteraction() {
        interaction.updateTransientInteraction(
            isHeaderPresented || isCreateListPresented || isErrorPresented || isRowPresented
        )
    }

}

private struct SyncErrorPresenter: View {
    let store: RemindersStore
    let onPresentationChange: (Bool) -> Void

    var body: some View {
        Color.clear
            .alert(
                "Reminders Error",
                isPresented: isErrorPresented
            ) {
                Button("OK") {
                    store.clearSyncError()
                }
            } message: {
                Text(store.syncErrorMessage ?? "Please try again.")
            }
            .onChange(of: store.syncErrorMessage, initial: true) { _, message in
                onPresentationChange(message != nil)
            }
            .onDisappear {
                onPresentationChange(false)
            }
    }

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { store.syncErrorMessage != nil },
            set: { presented in
                if !presented {
                    store.clearSyncError()
                }
            }
        )
    }
}
