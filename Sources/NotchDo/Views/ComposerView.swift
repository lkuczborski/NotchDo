import SwiftUI

struct ComposerView: View {
    let store: RemindersStore
    let isActive: Bool
    let onInteraction: () -> Void

    @State private var title = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 9) {
            ZStack(alignment: .leading) {
                if title.isEmpty {
                    Text("New reminder")
                        .foregroundStyle(.white.opacity(0.5))
                        .allowsHitTesting(false)
                }

                TextField("", text: $title)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white.opacity(0.84))
                    .focused($isFocused)
                    .onSubmit(submit)
                    .accessibilityLabel("New reminder")
            }
            .font(.system(size: 13.5, weight: .medium, design: .rounded))

            Button(action: submit) {
                Group {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white.opacity(0.42))
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                canSubmit
                                    ? store.selectedCalendarColor.opacity(0.82)
                                    : .white.opacity(0.38)
                            )
                    }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .accessibilityLabel("Add reminder")
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    isFocused ? .white.opacity(0.17) : .white.opacity(0.085),
                    lineWidth: 1
                )
        }
        .animation(.easeOut(duration: 0.12), value: isFocused)
        .simultaneousGesture(
            TapGesture().onEnded(onInteraction)
        )
        .onAppear {
            updateFocus()
        }
        .onChange(of: isActive) { _, _ in
            updateFocus()
        }
        .onChange(of: store.authorization) { _, _ in
            updateFocus()
        }
    }

    private var canSubmit: Bool {
        store.authorization == .fullAccess
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    private func submit() {
        guard canSubmit else { return }
        let submittedTitle = title
        title = ""
        isSaving = true

        Task {
            let didSave = await store.addReminder(title: submittedTitle)
            if !didSave {
                title = submittedTitle
            }
            isSaving = false
            isFocused = true
        }
    }

    private func updateFocus() {
        guard isActive, store.authorization == .fullAccess else {
            isFocused = false
            return
        }

        DispatchQueue.main.async {
            guard isActive, store.authorization == .fullAccess else { return }
            isFocused = true
        }
    }
}
