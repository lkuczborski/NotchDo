import SwiftUI

struct QuickCaptureView: View {
    let store: RemindersStore
    @Bindable var session: QuickCaptureSession
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case notes
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.authorization == .fullAccess {
                captureForm
            } else {
                accessView
            }
        }
        .frame(width: 660)
        .frame(height: 220)
        .preferredColorScheme(.dark)
        .onAppear {
            focusTitle()
            Task { await store.refreshAuthorization() }
        }
        .onChange(of: store.authorization) { _, authorization in
            if authorization == .fullAccess { focusTitle() }
        }
        .onChange(of: session.presentationID) { _, _ in
            focusTitle()
        }
        .onExitCommand(perform: onDismiss)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick reminder")
    }

    private var captureForm: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityHidden(true)

                TextField("What do you want to remember?", text: $session.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .focused($focusedField, equals: .title)
                    .onSubmit(submit)
                    .accessibilityLabel("Reminder title")

                if session.isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 72)

            Divider().opacity(0.5)

            TextField("Notes (optional)", text: $session.notes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...2)
                .font(.system(size: 14, design: .rounded))
                .focused($focusedField, equals: .notes)
                .padding(.horizontal, 24)
                .frame(minHeight: 48)
                .accessibilityLabel("Reminder notes")

            Divider().opacity(0.35)

            HStack(spacing: 12) {
                listPicker
                dueDateControl

                Spacer(minLength: 8)

                Text("esc")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Button(action: submit) {
                    Label("Add Reminder", systemImage: "return")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!session.canSubmit)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 20)
            .frame(height: 62)

            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityLabel("Could not add reminder: \(errorMessage)")
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.01 : 0.16), value: session.errorMessage)
    }

    private var listPicker: some View {
        Picker("List", selection: $session.calendarIdentifier) {
            ForEach(store.writableCalendars, id: \.calendarIdentifier) { calendar in
                Text(calendar.title).tag(Optional(calendar.calendarIdentifier))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
        .accessibilityLabel("Reminder list")
    }

    @ViewBuilder
    private var dueDateControl: some View {
        if session.includesDueDate {
            HStack(spacing: 5) {
                DatePicker(
                    "Due",
                    selection: $session.dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .fixedSize()

                Button {
                    session.includesDueDate = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear due date")
            }
        } else {
            Button {
                session.includesDueDate = true
            } label: {
                Label("Add Date", systemImage: "calendar")
            }
            .buttonStyle(.borderless)
        }
    }

    private var accessView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("Reminders access is needed")
                .font(.headline)
            Text("NotchDo saves quick captures directly to Apple Reminders.")
                .foregroundStyle(.secondary)

            if store.authorization == .notDetermined {
                Button("Continue") {
                    Task { await store.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else if store.authorization == .requesting {
                ProgressView()
            } else {
                Button("Open Privacy Settings", action: AppActions.openRemindersPrivacySettings)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 172)
        .padding(24)
    }

    private func focusTitle() {
        DispatchQueue.main.async { focusedField = .title }
    }

    private func submit() {
        Task {
            if await session.submit() {
                onDismiss()
            } else {
                focusTitle()
            }
        }
    }
}
