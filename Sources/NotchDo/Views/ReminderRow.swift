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
    let onUpdate: (ReminderDraft, Set<ReminderEditField>) async -> ReminderUpdateResult
    let onComplete: () async -> Bool

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
        onUpdate: @escaping (
            ReminderDraft,
            Set<ReminderEditField>
        ) async -> ReminderUpdateResult,
        onComplete: @escaping () async -> Bool
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
        .contextMenu {
            quickScheduleActions
        }
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

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    TextField(
                        "Reminder title",
                        text: draftBinding(\.title, field: .title)
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(height: 22)
                    .focused($titleFocused)
                    .accessibilityLabel("Reminder title")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button(action: expand) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.84))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 22, alignment: .center)

                        metadata
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(displayTitle)
                .accessibilityHint("Opens reminder details for editing")
                .accessibilityActions {
                    Button("Schedule for Today") {
                        applyQuickSchedule(.today)
                    }
                    Button("Schedule for Tomorrow") {
                        applyQuickSchedule(.tomorrow)
                    }
                    Button("Schedule for Next Week") {
                        applyQuickSchedule(.nextWeek)
                    }
                    if quickScheduleDueMode != .none {
                        Button("Clear Due Date") {
                            applyQuickSchedule(.clearDate)
                        }
                    }
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
                            selection: draftBinding(\.dueDate, field: .dueDate),
                            onPresentationChange: onTransientInteraction,
                            onQuickSchedule: applyQuickSchedule
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
                        ValidatingTimeField(
                            selection: draftBinding(\.dueDate, field: .dueDate)
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 24, alignment: .center)

            HStack(spacing: 18) {
                detailPicker(
                    "Priority",
                    selection: draftBinding(\.priority, field: .priority)
                ) {
                    ForEach(ReminderPriorityOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                detailPicker(
                    "Repeat",
                    selection: draftBinding(\.recurrence, field: .recurrence)
                ) {
                    ForEach(visibleRecurrenceOptions) { option in
                        Text(option.title).tag(option)
                    }
                }
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

                TextEditor(text: draftBinding(\.notes, field: .notes))
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

    @ViewBuilder
    private var quickScheduleActions: some View {
        ForEach(ReminderQuickSchedule.allCases) { schedule in
            if schedule == .clearDate {
                Divider()
            }
            Button {
                applyQuickSchedule(schedule)
            } label: {
                Label(schedule.title, systemImage: schedule.systemImage)
            }
            .disabled(schedule == .clearDate && quickScheduleDueMode == .none)
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

    private func applyQuickSchedule(_ schedule: ReminderQuickSchedule) {
        draft.reconcileDueFields(
            from: reminder,
            preservingLocalEdits: pendingFields.contains(.dueDate)
        )
        guard schedule != .clearDate || draft.dueMode != .none else { return }
        schedule.apply(to: &draft)
        queueSave(.dueDate)
    }

    private var quickScheduleDueMode: ReminderDueMode {
        pendingFields.contains(.dueDate) ? draft.dueMode : dueMode
    }

    private func draftBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<ReminderDraft, Value>,
        field: ReminderEditField
    ) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { newValue in
                guard draft[keyPath: keyPath] != newValue else { return }
                draft[keyPath: keyPath] = newValue
                queueSave(field)
            }
        )
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { draft.hasDueDate },
            set: { enabled in
                guard draft.hasDueDate != enabled else { return }
                draft.setDueDateEnabled(enabled)
                queueSave(.dueDate)
            }
        )
    }

    private var dueTimeEnabled: Binding<Bool> {
        Binding(
            get: { draft.hasDueTime },
            set: { enabled in
                guard draft.hasDueTime != enabled else { return }
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
        Task { @MainActor in
            let result = await onUpdate(snapshot, fields)
            reconcileDraft(after: result, fields: fields, snapshot: snapshot)
        }
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
        let snapshot = draft
        pendingFields.removeAll()
        let result = await onUpdate(snapshot, fields)
        reconcileDraft(after: result, fields: fields, snapshot: snapshot)
    }

    private func complete() {
        guard !isCompleting else { return }
        flushPendingSave()
        withAnimation(.smooth(duration: 0.16, extraBounce: 0)) {
            isCompleting = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            let completed = await onComplete()
            guard !completed else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                isCompleting = false
            }
        }
    }

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        DispatchQueue.main.async {
            titleFocused = true
        }
    }

    private func reconcileDraft(
        after result: ReminderUpdateResult,
        fields: Set<ReminderEditField>,
        snapshot: ReminderDraft
    ) {
        let fieldsToRestore = result.succeeded ? result.rejectedFields : fields
        guard !fieldsToRestore.isEmpty else { return }

        let canonical = ReminderDraft(reminder: reminder)
        for field in fieldsToRestore {
            restoreField(field, from: canonical, ifUnchangedSince: snapshot)
        }
    }

    private func restoreField(
        _ field: ReminderEditField,
        from canonical: ReminderDraft,
        ifUnchangedSince snapshot: ReminderDraft
    ) {
        switch field {
        case .title:
            guard draft.title == snapshot.title,
                  draft.title != canonical.title else { return }
            draft.title = canonical.title
        case .notes:
            guard draft.notes == snapshot.notes,
                  draft.notes != canonical.notes else { return }
            draft.notes = canonical.notes
        case .dueDate:
            guard draft.hasDueDate == snapshot.hasDueDate,
                  draft.hasDueTime == snapshot.hasDueTime,
                  draft.dueDate == snapshot.dueDate else { return }
            draft.hasDueDate = canonical.hasDueDate
            draft.hasDueTime = canonical.hasDueTime
            draft.dueDate = canonical.dueDate
        case .priority:
            guard draft.priority == snapshot.priority,
                  draft.priority != canonical.priority else { return }
            draft.priority = canonical.priority
        case .recurrence:
            guard draft.recurrence == snapshot.recurrence,
                  draft.recurrence != canonical.recurrence else { return }
            draft.recurrence = canonical.recurrence
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
