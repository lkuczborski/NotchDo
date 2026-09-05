import SwiftUI

struct QuickCaptureView: View {
    let store: RemindersStore
    @Bindable var session: QuickCaptureSession
    let onDismiss: () -> Void
    var onHeightChange: (CGFloat) -> Void = { _ in }

    @FocusState private var titleFocused: Bool
    @State private var showsNotes = false
    @State private var showsCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.authorization == .fullAccess {
                titleField
                shortcuts
                    .disabled(session.isSaving)
                if let error = session.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if store.writableCalendars.isEmpty {
                    Text("Create a writable list in Reminders to add a task.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                accessView
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 620)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(QuickCaptureSurface())
        // Keep the rounded surface and its soft shadow clear of window bounds.
        .padding(20)
        .background {
            GeometryReader { geometry in
                Color.clear.onChange(of: geometry.size.height, initial: true) { _, height in
                    onHeightChange(height)
                }
            }
        }
        .onAppear { titleFocused = true }
        .onChange(of: session.presentationID) { _, _ in
            showsNotes = false
            showsCalendar = false
            titleFocused = true
        }
        .onChange(of: store.writableCalendars.map(\.calendarIdentifier)) { _, _ in
            session.reconcileDestination()
        }
        .onChange(of: store.authorization) { _, _ in titleFocused = true }
        .onChange(of: showsCalendar) { _, visible in if !visible { titleFocused = true } }
        .onChange(of: showsNotes) { _, visible in if !visible { titleFocused = true } }
        .onExitCommand {
            if showsNotes || showsCalendar {
                showsNotes = false
                showsCalendar = false
            } else {
                onDismiss()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick reminder")
    }

    private var titleField: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            TextField("What’s on your mind?", text: $session.title)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .focused($titleFocused)
                .disabled(session.isSaving)
                .onSubmit(submit)
                .accessibilityLabel("Reminder title")
            Button(action: submit) {
                Group {
                    if session.isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up").font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 32, height: 32)
                .foregroundStyle(session.canSubmit ? Color.white : Color.secondary)
                .background(session.canSubmit ? Color.accentColor : Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!session.canSubmit)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel("Add reminder")
            .help("Add reminder (Return)")
        }
        .frame(height: 36)
    }

    private var shortcuts: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(store.writableCalendars, id: \.calendarIdentifier) { calendar in
                    Button {
                        session.calendarIdentifier = calendar.calendarIdentifier
                    } label: {
                        if session.calendarIdentifier == calendar.calendarIdentifier {
                            Label(calendar.title, systemImage: "checkmark")
                        } else {
                            Text(calendar.title)
                        }
                    }
                }
            } label: {
                Label(destinationTitle, systemImage: "tray")
                    .lineLimit(1).frame(maxWidth: 100)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            .capturePill()
            .disabled(store.writableCalendars.isEmpty)
            .accessibilityLabel("Reminder list, \(destinationTitle)")

            ForEach([ReminderQuickSchedule.today, .tomorrow, .nextWeek]) { schedule in
                Button {
                    session.schedule(session.isScheduled(schedule) ? .clearDate : schedule)
                } label: {
                    Text(schedule.title)
                        .capturePill(selected: session.isScheduled(schedule))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(session.isScheduled(schedule) ? .isSelected : [])
            }

            Button { showsCalendar.toggle() } label: {
                Group {
                    if session.includesDueDate && !hasQuickDate {
                        Text(session.dueDate, format: .dateTime.month(.abbreviated).day())
                    } else {
                        Image(systemName: "calendar")
                    }
                }
                .capturePill(selected: session.includesDueDate && !hasQuickDate)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose another date")
            .popover(isPresented: $showsCalendar) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Due date").font(.headline)
                    DatePicker("Due date", selection: $session.dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChange(of: session.dueDate) { _, _ in session.includesDueDate = true }
                    HStack {
                        Button("Clear date") {
                            session.includesDueDate = false
                            showsCalendar = false
                        }
                        Spacer()
                        Button("Done") {
                            session.includesDueDate = true
                            showsCalendar = false
                        }.keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
                .onExitCommand { showsCalendar = false }
            }

            Spacer(minLength: 0)
            Button { showsNotes.toggle() } label: {
                Image(systemName: "note.text")
                    .capturePill(selected: !session.notes.isEmpty)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reminder notes")
            .popover(isPresented: $showsNotes) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes").font(.headline)
                    TextField("Add a little detail…", text: $session.notes, axis: .vertical)
                        .lineLimit(3...6).textFieldStyle(.plain).frame(width: 300)
                    Button("Done") { showsNotes = false }.keyboardShortcut(.defaultAction)
                }
                .padding(16)
                .onExitCommand { showsNotes = false }
            }
        }
        .font(.system(size: 11, weight: .medium))
    }

    private var destinationTitle: String {
        store.writableCalendars.first { $0.calendarIdentifier == session.calendarIdentifier }?.title ?? "No list"
    }

    private var hasQuickDate: Bool {
        [ReminderQuickSchedule.today, .tomorrow, .nextWeek].contains(where: session.isScheduled)
    }

    private var accessView: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock").font(.title2).foregroundStyle(.secondary)
            Text("Allow Reminders access to capture a task.").font(.callout)
            Spacer()
            if store.authorization == .requesting {
                ProgressView().controlSize(.small)
            } else if store.authorization == .notDetermined {
                Button("Continue") { Task { await store.requestAccess() } }
            } else {
                Button("Settings", action: AppActions.openRemindersPrivacySettings)
            }
        }.frame(minHeight: 60)
    }

    private func submit() {
        let presentation = session.presentationID
        Task {
            guard session.presentationID == presentation else { return }
            let saved = await session.submit()
            guard session.presentationID == presentation else { return }
            if saved { onDismiss() }
        }
    }
}
