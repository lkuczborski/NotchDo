import EventKit
import SwiftUI

struct ReminderRow: View {
    let reminder: EKReminder
    @ObservedObject var store: RemindersStore
    @Binding var isExpanded: Bool
    let onHoverChange: (Bool) -> Void

    @State private var draft: ReminderDraft
    @State private var isCompleting = false
    @State private var isHovering = false
    @State private var pendingFields: Set<ReminderEditField> = []
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var titleFocused: Bool

    init(
        reminder: EKReminder,
        store: RemindersStore,
        isExpanded: Binding<Bool>,
        onHoverChange: @escaping (Bool) -> Void
    ) {
        self.reminder = reminder
        self.store = store
        _isExpanded = isExpanded
        self.onHoverChange = onHoverChange
        _draft = State(initialValue: ReminderDraft(reminder: reminder))
    }

    var body: some View {
        VStack(spacing: 0) {
            summary

            if isExpanded {
                editor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            .white.opacity(rowBackgroundOpacity),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(rowStrokeOpacity), lineWidth: 1)
        }
        .scaleEffect(isHovering && !isExpanded ? 1.004 : 1)
        .animation(.smooth(duration: 0.22, extraBounce: 0), value: isExpanded)
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            onHoverChange(hovering)
        }
        .onChange(of: isExpanded) { _, rowIsExpanded in
            guard !rowIsExpanded else { return }
            flushPendingSave()
            titleFocused = false
        }
        .onDisappear {
            saveTask?.cancel()
        }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 10) {
            completionControl

            VStack(alignment: .leading, spacing: 4) {
                if isExpanded {
                    TextField("Reminder title", text: $draft.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .focused($titleFocused)
                        .onChange(of: draft.title) { _, _ in queueSave(.title) }
                } else {
                    Text(displayTitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

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
            Divider()
                .overlay(.white.opacity(0.05))

            HStack(spacing: 9) {
                Label("Due", systemImage: "calendar")
                    .frame(width: 58, alignment: .leading)

                Toggle("", isOn: $draft.hasDueDate)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: draft.hasDueDate) { _, _ in queueSave(.dueDate) }

                if draft.hasDueDate {
                    DatePicker(
                        "",
                        selection: $draft.dueDate,
                        displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .controlSize(.small)
                    .onChange(of: draft.dueDate) { _, _ in queueSave(.dueDate) }

                    Toggle("All day", isOn: $draft.isAllDay)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .onChange(of: draft.isAllDay) { _, _ in queueSave(.dueDate) }
                }
            }

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
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draft.notes)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 48, maxHeight: 70)
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
        .foregroundStyle(.white.opacity(0.42))
        .padding(.horizontal, 11)
        .padding(.bottom, 11)
    }

    private var completionControl: some View {
        ZStack {
            Circle()
                .stroke(
                    store.selectedCalendarColor.opacity(isHovering ? 0.62 : 0.46),
                    lineWidth: 1.25
                )
                .frame(width: 18, height: 18)

            if isCompleting {
                Circle()
                    .fill(store.selectedCalendarColor)
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
        let due = reminder.notchDueMetadata
        let priority = reminder.notchPrioritySymbol
        let hasNotes = !(reminder.notes ?? "").isEmpty
        let repeats = !(reminder.recurrenceRules ?? []).isEmpty

        if due != nil || priority != nil || hasNotes || repeats {
            HStack(spacing: 8) {
                if let due {
                    Label(due.text, systemImage: "calendar")
                        .foregroundStyle(due.isOverdue ? Color.red.opacity(0.72) : .white.opacity(0.3))
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
            .foregroundStyle(.white.opacity(0.27))
        }
    }

    private func detailPicker<Selection: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .foregroundStyle(.white.opacity(0.34))
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
        }
    }

    private var visibleRecurrenceOptions: [ReminderRecurrenceOption] {
        ReminderRecurrenceOption.allCases.filter {
            $0 != .custom || draft.recurrence == .custom
        }
    }

    private var rowBackgroundOpacity: Double {
        if isExpanded { return 0.038 }
        return isHovering ? 0.048 : 0.025
    }

    private var rowStrokeOpacity: Double {
        if isExpanded { return 0.065 }
        return isHovering ? 0.075 : 0.038
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

    private func flushPendingSave() {
        saveTask?.cancel()
        saveTask = nil
        guard !pendingFields.isEmpty else { return }
        let fields = pendingFields
        let snapshot = draft
        pendingFields.removeAll()
        Task { await store.update(reminder, with: snapshot, fields: fields) }
    }

    @MainActor
    private func savePendingFields() async {
        let fields = pendingFields
        guard !fields.isEmpty else { return }
        pendingFields.removeAll()
        await store.update(reminder, with: draft, fields: fields)
    }

    private func complete() {
        guard !isCompleting else { return }
        flushPendingSave()
        withAnimation(.smooth(duration: 0.16, extraBounce: 0)) {
            isCompleting = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            await store.setCompleted(reminder)
        }
    }

    private var displayTitle: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled reminder" : title
    }
}
