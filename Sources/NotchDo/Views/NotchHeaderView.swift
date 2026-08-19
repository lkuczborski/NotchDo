import AppKit
import EventKit
import SwiftUI

struct NotchHeaderView: View {
    let store: RemindersStore
    let onInteraction: () -> Void
    let onTransientInteractionChange: (Bool) -> Void

    @State private var isCalendarPickerPresented = false
    @State private var isOptionsPresented = false
    @State private var isCreateListPresented = false
    @State private var newListTitle = ""
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            listSelector

            Spacer(minLength: 10)

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

                Text(store.selectedCalendarTitle)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.42))
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 300, alignment: .leading)
        .popover(isPresented: $isCalendarPickerPresented, arrowEdge: .top) {
            calendarList
        }
        .onChange(of: isCalendarPickerPresented) { _, _ in
            reportTransientInteraction()
        }
        .accessibilityLabel(
            "Reminder list: \(store.selectedCalendarTitle), \(store.reminders.count) reminders"
        )
        .alert("New Reminder List", isPresented: $isCreateListPresented) {
            TextField("List name", text: $newListTitle)
            Button("Cancel", role: .cancel) {
                newListTitle = ""
            }
            Button("Create") {
                let title = newListTitle
                newListTitle = ""
                Task {
                    if await store.createCalendar(title: title) {
                        isCalendarPickerPresented = false
                    }
                }
            }
            .disabled(newListTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("The list is created directly in Reminders using EventKit.")
        }
    }

    private var calendarList: some View {
        VStack(alignment: .leading, spacing: 6) {
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

                                    if calendar.calendarIdentifier
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
                        }
                    }
                }
                .frame(maxHeight: 190)
            }

            Divider()
                .padding(.vertical, 2)

            Button {
                isCreateListPresented = true
            } label: {
                Label("New List", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(7)
        .frame(width: 224)
        .preferredColorScheme(.dark)
    }

    private var options: some View {
        VStack(spacing: 2) {
            optionButton("Refresh", systemImage: "arrow.clockwise") {
                isOptionsPresented = false
                Task { await store.reload() }
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
            isCalendarPickerPresented || isOptionsPresented || isCreateListPresented
        )
    }

}
