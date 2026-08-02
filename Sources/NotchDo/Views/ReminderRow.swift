import AppKit
import EventKit
import SwiftUI

struct ReminderRow: View {
    let reminder: EKReminder
    let calendarColor: Color
    let dueMode: ReminderDueMode
    @Binding var isExpanded: Bool
    let onTransientInteraction: (Bool) -> Void
    let isReminderPresent: () -> Bool
    let onUpdate: (ReminderDraft, Set<ReminderEditField>) async -> Void
    let onComplete: () async -> Void

    @State private var draft: ReminderDraft
    @State private var isCompleting = false
    @State private var pendingFields: Set<ReminderEditField> = []
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var titleFocused: Bool

    init(
        reminder: EKReminder,
        calendarColor: Color,
        dueMode: ReminderDueMode,
        isExpanded: Binding<Bool>,
        onTransientInteraction: @escaping (Bool) -> Void,
        isReminderPresent: @escaping () -> Bool,
        onUpdate: @escaping (ReminderDraft, Set<ReminderEditField>) async -> Void,
        onComplete: @escaping () async -> Void
    ) {
        self.reminder = reminder
        self.calendarColor = calendarColor
        self.dueMode = dueMode
        _isExpanded = isExpanded
        self.onTransientInteraction = onTransientInteraction
        self.isReminderPresent = isReminderPresent
        self.onUpdate = onUpdate
        self.onComplete = onComplete
        _draft = State(initialValue: ReminderDraft(reminder: reminder, dueMode: dueMode))
    }

    var body: some View {
        VStack(spacing: 0) {
            summary

            if isExpanded {
                editor
            }
        }
        .background(
            rowBackgroundColor,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: rowStrokeWidth)
        }
        .tint(calendarColor)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onChange(of: isExpanded) { _, rowIsExpanded in
            guard !rowIsExpanded else { return }
            flushPendingSave()
            titleFocused = false
        }
        .onDisappear(perform: handleDisappear)
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 10) {
            completionControl

            VStack(alignment: .leading, spacing: 4) {
                if isExpanded {
                    TextField("Reminder title", text: $draft.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                        .frame(height: 22)
                        .focused($titleFocused)
                        .accessibilityLabel("Reminder title")
                        .onChange(of: draft.title) { _, _ in queueSave(.title) }
                } else {
                    Text(displayTitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 22, alignment: .center)

                    metadata
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isExpanded else { return }
                isExpanded = true
                DispatchQueue.main.async {
                    titleFocused = true
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 12) {
                dueControlGroup(systemImage: "calendar") {
                    Toggle("Date", isOn: dueDateEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .fixedSize()
                        .accessibilityLabel("Due date")
                        .accessibilityValue(draft.hasDueDate ? "On" : "Off")

                    if draft.hasDueDate {
                        CenteredDateField(
                            selection: $draft.dueDate,
                            onPresentationChange: onTransientInteraction
                        )
                    }
                }

                dueControlGroup(systemImage: "clock") {
                    Toggle("Time", isOn: dueTimeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .fixedSize()
                        .accessibilityLabel("Due time")
                        .accessibilityValue(draft.hasDueTime ? "On" : "Off")

                    if draft.hasDueTime {
                        ValidatingTimeField(selection: $draft.dueDate)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 24, alignment: .center)
            .onChange(of: draft.dueDate) { _, _ in queueSave(.dueDate) }

            HStack(spacing: 18) {
                detailPicker("Priority", selection: $draft.priority) {
                    ForEach(ReminderPriorityOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .onChange(of: draft.priority) { _, _ in queueSave(.priority) }

                detailPicker("Repeat", selection: $draft.recurrence) {
                    ForEach(visibleRecurrenceOptions) { option in
                        Text(option.title).tag(option)
                    }
                }
                .onChange(of: draft.recurrence) { _, _ in queueSave(.recurrence) }
            }

            ZStack(alignment: .topLeading) {
                if draft.notes.isEmpty {
                    Text("Notes")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draft.notes)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .scrollContentBackground(.hidden)
                    .padding(.leading, 5.5)
                    .padding(.trailing, 4)
                    .padding(.top, 8)
                    .frame(minHeight: 48, maxHeight: 70)
                    .accessibilityLabel("Notes")
                    .onKeyPress(phases: .down) { press in
                        guard press.key == .tab else { return .ignored }
                        advanceKeyView(backward: press.modifiers.contains(.shift))
                        return .handled
                    }
                    .onChange(of: draft.notes) { _, _ in queueSave(.notes) }
            }
            .background(
                .white.opacity(0.022),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.055), lineWidth: 1)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.52))
        .padding(.horizontal, 11)
        .padding(.bottom, 11)
    }

    private var completionControl: some View {
        ZStack {
            Circle()
                .stroke(
                    calendarColor.opacity(isExpanded ? 0.68 : 0.46),
                    lineWidth: 1.25
                )
                .frame(width: 18, height: 18)

            if isCompleting {
                Circle()
                    .fill(calendarColor)
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.black.opacity(0.72))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 22)
        .contentShape(Circle())
        .onTapGesture(perform: complete)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Complete \(displayTitle)")
        .accessibilityAction {
            complete()
        }
    }

    @ViewBuilder
    private var metadata: some View {
        let due = reminder.notchDueMetadata(mode: dueMode)
        let priority = reminder.notchPrioritySymbol
        let hasNotes = !(reminder.notes ?? "").isEmpty
        let repeats = !(reminder.recurrenceRules ?? []).isEmpty

        if due != nil || priority != nil || hasNotes || repeats {
            HStack(spacing: 8) {
                if let due {
                    Label(due.text, systemImage: "calendar")
                        .foregroundStyle(
                            due.isOverdue
                                ? Color.red.opacity(0.9)
                                : .white.opacity(0.55)
                        )
                }
                if let priority {
                    Text(priority)
                        .foregroundStyle(Color.orange.opacity(0.68))
                }
                if hasNotes {
                    Image(systemName: "note.text")
                }
                if repeats {
                    Image(systemName: "repeat")
                }
            }
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.leading, -5)
        }
    }

    private func detailPicker<Selection: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .foregroundStyle(.white.opacity(0.48))
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityLabel(title)
        }
    }

    private func dueControlGroup<Content: View>(
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .frame(width: 13)
                .accessibilityHidden(true)
            content()
        }
    }

    private var visibleRecurrenceOptions: [ReminderRecurrenceOption] {
        ReminderRecurrenceOption.allCases.filter {
            $0 != .custom || draft.recurrence == .custom
        }
    }

    private var rowBackgroundColor: Color {
        if isExpanded {
            return calendarColor.opacity(0.115)
        }
        return .white.opacity(0.025)
    }

    private var rowStrokeColor: Color {
        if isExpanded {
            return calendarColor.opacity(0.58)
        }
        return .white.opacity(0.038)
    }

    private var rowStrokeWidth: CGFloat {
        isExpanded ? 1.5 : 1
    }

    private func queueSave(_ field: ReminderEditField) {
        pendingFields.insert(field)
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await savePendingFields()
        }
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { draft.hasDueDate },
            set: { enabled in
                draft.setDueDateEnabled(enabled)
                queueSave(.dueDate)
            }
        )
    }

    private var dueTimeEnabled: Binding<Bool> {
        Binding(
            get: { draft.hasDueTime },
            set: { enabled in
                draft.setDueTimeEnabled(enabled)
                queueSave(.dueDate)
            }
        )
    }

    private func flushPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        guard !pendingFields.isEmpty else { return }
        let fields = pendingFields
        let snapshot = draft
        pendingFields.removeAll()
        Task { await onUpdate(snapshot, fields) }
    }

    private func handleDisappear() {
        if isReminderPresent() {
            flushPendingSave()
        } else {
            saveTask?.cancel()
            saveTask = nil
        }
    }

    @MainActor
    private func savePendingFields() async {
        let fields = pendingFields
        guard !fields.isEmpty else { return }
        pendingFields.removeAll()
        await onUpdate(draft, fields)
    }

    private func complete() {
        guard !isCompleting else { return }
        flushPendingSave()
        withAnimation(.smooth(duration: 0.16, extraBounce: 0)) {
            isCompleting = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            await onComplete()
        }
    }

    private var displayTitle: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled reminder" : title
    }

    private func advanceKeyView(backward: Bool) {
        guard let window = NSApp.keyWindow else { return }
        if backward {
            window.selectPreviousKeyView(nil)
        } else {
            window.selectNextKeyView(nil)
        }
    }
}
