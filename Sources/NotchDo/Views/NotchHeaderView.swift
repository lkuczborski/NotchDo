import AppKit
import EventKit
import SwiftUI

struct NotchHeaderView: View {
    let store: RemindersStore
    let onInteraction: () -> Void
    let onSearch: () -> Void
    let onTransientInteractionChange: (Bool) -> Void
    let onCreateList: () -> Void

    @State private var isCalendarPickerPresented = false
    @State private var isOptionsPresented = false
    @FocusState private var focusedPickerSelection: ReminderPickerSelection?
    @Environment(\.openSettings) private var openSettings

    init(
        store: RemindersStore,
        onInteraction: @escaping () -> Void,
        onSearch: @escaping () -> Void,
        onTransientInteractionChange: @escaping (Bool) -> Void,
        onCreateList: @escaping () -> Void
    ) {
        self.store = store
        self.onInteraction = onInteraction
        self.onSearch = onSearch
        self.onTransientInteractionChange = onTransientInteractionChange
        self.onCreateList = onCreateList
    }

    var body: some View {
        HStack(spacing: 12) {
            listSelector

            Spacer(minLength: 10)

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.07), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("Search reminders")
            .help("Search Reminders (Command-F)")

            Button {
                isOptionsPresented.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.07), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 30, height: 30)
            .popover(isPresented: $isOptionsPresented, arrowEdge: .top) {
                options
            }
            .onChange(of: isOptionsPresented) { _, _ in
                reportTransientInteraction()
            }
            .accessibilityLabel("NotchDo menu")
        }
        .simultaneousGesture(
            TapGesture().onEnded(onInteraction)
        )
    }

    private var listSelector: some View {
        Button {
            isCalendarPickerPresented.toggle()
        } label: {
            HStack(spacing: 10) {
                TaskCountBadgeTarget()

                HStack(spacing: 7) {
                    Text(store.selectedCalendarTitle)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if store.authorization == .fullAccess {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.42))
                            .font(.system(size: 9, weight: .bold))
                    }
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 300, alignment: .leading)
        .disabled(store.authorization != .fullAccess)
        .popover(isPresented: $isCalendarPickerPresented, arrowEdge: .top) {
            calendarList
        }
        .onChange(of: isCalendarPickerPresented) { _, _ in
            reportTransientInteraction()
        }
        .accessibilityLabel(listSelectorAccessibilityLabel)
    }

    private var calendarList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Smart Lists")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.top, 3)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 2
            ) {
                ForEach(ReminderSmartScope.allCases) { scope in
                    Button {
                        store.selectSmartScope(scope)
                        isCalendarPickerPresented = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.systemImage)
                                .frame(width: 12)
                                .foregroundStyle(Color.notchAccent)
                            Text(scope.title)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                        }
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(
                            Color.black.opacity(store.selectedSmartScope == scope ? 0.3 : 0),
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .focusEffectDisabled()
                    .focused($focusedPickerSelection, equals: .smart(scope))
                    .accessibilityLabel("Show \(scope.title) reminders")
                    .accessibilityAddTraits(store.selectedSmartScope == scope ? .isSelected : [])
                }
            }

            Divider()
                .padding(.vertical, 2)

            Text("Lists")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.top, 3)

            if store.calendars.isEmpty {
                Text("No reminder lists")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                            Button {
                                store.selectCalendar(calendar.calendarIdentifier)
                                isCalendarPickerPresented = false
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(calendar.notchColor)
                                        .frame(width: 8, height: 8)

                                    Text(calendar.title)
                                        .lineLimit(1)

                                    Spacer(minLength: 12)

                                    if store.selectedSmartScope == nil,
                                       calendar.calendarIdentifier
                                        == store.selectedCalendarIdentifier {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(calendar.notchColor)
                                    }
                                }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .frame(height: 30)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .focusable()
                            .focusEffectDisabled()
                            .focused(
                                $focusedPickerSelection,
                                equals: .calendar(calendar.calendarIdentifier)
                            )
                            .accessibilityLabel("Show \(calendar.title) reminder list")
                        }
                    }
                }
                .frame(maxHeight: 190)
            }

            Divider()
                .padding(.vertical, 2)

            Button {
                isCalendarPickerPresented = false
                onCreateList()
            } label: {
                Label("New List", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.authorization != .fullAccess)
        }
        .padding(7)
        .frame(width: 224)
        .preferredColorScheme(.dark)
        .onAppear(perform: focusCurrentPickerSelection)
        .onMoveCommand(perform: movePickerFocus)
    }

    private var options: some View {
        VStack(spacing: 2) {
            optionButton("Refresh", systemImage: "arrow.clockwise") {
                isOptionsPresented = false
                Task { await store.reload() }
            }

            optionButton("Quick Reminder…", systemImage: "bolt.fill") {
                isOptionsPresented = false
                AppActions.requestQuickCapture()
            }

            optionButton("Open Reminders", systemImage: "arrow.up.forward.app") {
                isOptionsPresented = false
                AppActions.openReminders()
            }

            optionButton("Settings…", systemImage: "gearshape") {
                isOptionsPresented = false
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()
                .padding(.vertical, 3)

            optionButton("Quit NotchDo", systemImage: "power", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
        .padding(7)
        .frame(width: 184)
        .preferredColorScheme(.dark)
    }

    private func optionButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reportTransientInteraction() {
        onTransientInteractionChange(
            isCalendarPickerPresented || isOptionsPresented
        )
    }

    private var pickerSelections: [ReminderPickerSelection] {
        ReminderSmartScope.allCases.map(ReminderPickerSelection.smart)
            + store.calendars.map { .calendar($0.calendarIdentifier) }
    }

    private func focusCurrentPickerSelection() {
        let selection = store.selectedSmartScope.map(ReminderPickerSelection.smart)
            ?? store.selectedCalendarIdentifier.map(ReminderPickerSelection.calendar)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard isCalendarPickerPresented else { return }
            focusedPickerSelection = selection
        }
    }

    private func movePickerFocus(_ direction: MoveCommandDirection) {
        guard direction == .up || direction == .down,
              !pickerSelections.isEmpty else { return }
        let currentIndex = focusedPickerSelection.flatMap(pickerSelections.firstIndex) ?? 0
        let offset = direction == .down ? 1 : -1
        let nextIndex = min(max(currentIndex + offset, 0), pickerSelections.count - 1)
        focusedPickerSelection = pickerSelections[nextIndex]
    }

    private var listSelectorAccessibilityLabel: String {
        let parts = [
            "Reminder list: \(store.selectedCalendarTitle)",
            "\(store.reminders.count) open reminders"
        ]
        return parts.joined(separator: ", ")
    }

}
